package main

import (
	"context"
	"database/sql"
	"errors"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib" // драйвер PostgreSQL для database/sql
)

// PGStore хранит заметки в PostgreSQL. Таблица создаётся при старте, если её нет.
type PGStore struct {
	db *sql.DB
}

// NewPGStore подключается к базе по строке вида postgres://user:pass@host:5432/db?sslmode=disable.
func NewPGStore(ctx context.Context, url string) (*PGStore, error) {
	db, err := sql.Open("pgx", url)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(10)
	db.SetConnMaxIdleTime(5 * time.Minute)
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	_, err = db.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS notes (
		id      BIGSERIAL PRIMARY KEY,
		text    TEXT NOT NULL,
		created TIMESTAMPTZ NOT NULL
	)`)
	if err != nil {
		db.Close()
		return nil, err
	}
	return &PGStore{db: db}, nil
}

func (s *PGStore) List(ctx context.Context) ([]Note, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, text, created FROM notes ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	list := []Note{}
	for rows.Next() {
		var n Note
		if err := rows.Scan(&n.ID, &n.Text, &n.Created); err != nil {
			return nil, err
		}
		n.Created = n.Created.UTC()
		list = append(list, n)
	}
	return list, rows.Err()
}

func (s *PGStore) Get(ctx context.Context, id int) (Note, error) {
	var n Note
	err := s.db.QueryRowContext(ctx, `SELECT id, text, created FROM notes WHERE id = $1`, id).Scan(&n.ID, &n.Text, &n.Created)
	if errors.Is(err, sql.ErrNoRows) {
		return Note{}, ErrNotFound
	}
	n.Created = n.Created.UTC()
	return n, err
}

func (s *PGStore) Add(ctx context.Context, text string, now time.Time) (Note, error) {
	n := Note{Text: text, Created: now.UTC()}
	err := s.db.QueryRowContext(ctx, `INSERT INTO notes (text, created) VALUES ($1, $2) RETURNING id`, text, n.Created).Scan(&n.ID)
	return n, err
}

func (s *PGStore) Delete(ctx context.Context, id int) error {
	res, err := s.db.ExecContext(ctx, `DELETE FROM notes WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *PGStore) Ping(ctx context.Context) error { return s.db.PingContext(ctx) }

func (s *PGStore) Close() error { return s.db.Close() }
