package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// storeContract — общие проверки для любого хранилища: файла и PostgreSQL.
func storeContract(t *testing.T, s Store) {
	t.Helper()
	ctx := context.Background()
	if err := s.Ping(ctx); err != nil {
		t.Fatalf("Ping: %v", err)
	}
	now := time.Date(2026, 11, 12, 7, 0, 0, 0, time.UTC)
	a, err := s.Add(ctx, "первая", now)
	if err != nil {
		t.Fatal(err)
	}
	b, _ := s.Add(ctx, "вторая", now)
	if b.ID <= a.ID {
		t.Fatalf("номера не растут: %d, %d", a.ID, b.ID)
	}
	got, err := s.Get(ctx, a.ID)
	if err != nil || got.Text != "первая" || !got.Created.Equal(now) {
		t.Fatalf("Get: %+v, %v", got, err)
	}
	if err := s.Delete(ctx, a.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Get(ctx, a.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("после удаления: %v", err)
	}
	if err := s.Delete(ctx, a.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("повторное удаление: %v", err)
	}
	list, err := s.List(ctx)
	if err != nil || len(list) != 1 || list[0].ID != b.ID {
		t.Fatalf("List: %+v, %v", list, err)
	}
}

func TestFileStoreContract(t *testing.T) {
	s, err := NewFileStore("")
	if err != nil {
		t.Fatal(err)
	}
	storeContract(t, s)
}

func TestFileStorePersistsBetweenRestarts(t *testing.T) {
	ctx := context.Background()
	dir := t.TempDir()
	s, err := NewFileStore(dir)
	if err != nil {
		t.Fatal(err)
	}
	s.Add(ctx, "первая", time.Now())
	second, _ := s.Add(ctx, "вторая", time.Now())
	s.Delete(ctx, 1)

	again, err := NewFileStore(dir)
	if err != nil {
		t.Fatal(err)
	}
	list, _ := again.List(ctx)
	if len(list) != 1 || list[0].ID != second.ID {
		t.Fatalf("после перезапуска %+v", list)
	}
	third, _ := again.Add(ctx, "третья", time.Now())
	if third.ID != 3 {
		t.Fatalf("номер новой заметки %d, ожидался 3", third.ID)
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 || entries[0].Name() != "notes.json" {
		t.Fatalf("в каталоге лишние файлы: %v", entries)
	}
}

func TestFileStoreRejectsBrokenFile(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "notes.json"), []byte("{битый"), 0o600)
	if _, err := NewFileStore(dir); err == nil {
		t.Fatal("битый файл должен давать ошибку, а не пустой список")
	}
}

// TestPGStoreContract запускается, только если задана тестовая база:
// NOTES_TEST_DATABASE_URL=postgres://notes:notes@127.0.0.1:5432/notes?sslmode=disable go test ./...
// Таблица notes в этой базе очищается.
func TestPGStoreContract(t *testing.T) {
	url := os.Getenv("NOTES_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("NOTES_TEST_DATABASE_URL не задан — тест PostgreSQL пропущен")
	}
	s, err := NewPGStore(context.Background(), url)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if _, err := s.db.Exec(`TRUNCATE notes RESTART IDENTITY`); err != nil {
		t.Fatal(err)
	}
	storeContract(t, s)
}
