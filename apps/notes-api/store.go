package main

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"
)

// Note — заметка.
type Note struct {
	ID      int       `json:"id"`
	Text    string    `json:"text"`
	Created time.Time `json:"created"`
}

// ErrNotFound — заметки с таким номером нет.
var ErrNotFound = errors.New("note not found")

// Store хранит заметки в памяти. Если задан dir, после каждого изменения
// записывает их в dir/notes.json (атомарно, через временный файл) и читает при старте —
// так заметки переживают перезапуск контейнера, если dir — том.
type Store struct {
	mu    sync.Mutex
	dir   string
	next  int
	notes map[int]Note
}

// NewStore открывает хранилище; dir == "" — только память.
func NewStore(dir string) (*Store, error) {
	s := &Store{dir: dir, next: 1, notes: map[int]Note{}}
	if dir == "" {
		return s, nil
	}
	data, err := os.ReadFile(filepath.Join(dir, "notes.json"))
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err != nil {
		return nil, err
	}
	var list []Note
	if err := json.Unmarshal(data, &list); err != nil {
		return nil, err
	}
	for _, n := range list {
		s.notes[n.ID] = n
		if n.ID >= s.next {
			s.next = n.ID + 1
		}
	}
	return s, nil
}

// List — все заметки по возрастанию номера.
func (s *Store) List() []Note {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.sorted()
}

func (s *Store) sorted() []Note {
	list := make([]Note, 0, len(s.notes))
	for _, n := range s.notes {
		list = append(list, n)
	}
	sort.Slice(list, func(i, j int) bool { return list[i].ID < list[j].ID })
	return list
}

// Get возвращает заметку или ErrNotFound.
func (s *Store) Get(id int) (Note, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	n, ok := s.notes[id]
	if !ok {
		return Note{}, ErrNotFound
	}
	return n, nil
}

// Add создаёт заметку.
func (s *Store) Add(text string, now time.Time) (Note, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	n := Note{ID: s.next, Text: text, Created: now.UTC()}
	s.notes[n.ID] = n
	s.next++
	if err := s.save(); err != nil {
		delete(s.notes, n.ID)
		s.next--
		return Note{}, err
	}
	return n, nil
}

// Delete удаляет заметку или возвращает ErrNotFound.
func (s *Store) Delete(id int) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	n, ok := s.notes[id]
	if !ok {
		return ErrNotFound
	}
	delete(s.notes, id)
	if err := s.save(); err != nil {
		s.notes[id] = n
		return err
	}
	return nil
}

// save пишет заметки на диск; вызывается под мьютексом.
func (s *Store) save() error {
	if s.dir == "" {
		return nil
	}
	data, err := json.Marshal(s.sorted())
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(s.dir, ".notes-*.json")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name()) // после успешного Rename файла уже нет — ошибка игнорируется
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), filepath.Join(s.dir, "notes.json"))
}
