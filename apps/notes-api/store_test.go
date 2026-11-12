package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestStorePersistsBetweenRestarts(t *testing.T) {
	dir := t.TempDir()
	s, err := NewStore(dir)
	if err != nil {
		t.Fatal(err)
	}
	s.Add("первая", time.Now())
	second, _ := s.Add("вторая", time.Now())
	s.Delete(1)

	again, err := NewStore(dir)
	if err != nil {
		t.Fatal(err)
	}
	list := again.List()
	if len(list) != 1 || list[0].ID != second.ID {
		t.Fatalf("после перезапуска %+v", list)
	}
	third, _ := again.Add("третья", time.Now())
	if third.ID != 3 {
		t.Fatalf("номер новой заметки %d, ожидался 3", third.ID)
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 || entries[0].Name() != "notes.json" {
		t.Fatalf("в каталоге лишние файлы: %v", entries)
	}
}

func TestStoreRejectsBrokenFile(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "notes.json"), []byte("{битый"), 0o600)
	if _, err := NewStore(dir); err == nil {
		t.Fatal("битый файл должен давать ошибку, а не пустой список")
	}
}
