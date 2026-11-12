package main

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"
)

// MaxTextLen — предел длины заметки в символах.
const MaxTextLen = 1000

// Сборка подставляет версию и коммит: go build -ldflags "-X main.version=1.2.0 -X main.commit=abc123".
var (
	version = "dev"
	commit  = "unknown"
)

// NewHandler — все маршруты сервиса. Шаблоны «МЕТОД /путь/{id}» — ServeMux из Go 1.22+.
func NewHandler(store *Store, now func() time.Time) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("GET /version", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"version": version, "commit": commit})
	})
	mux.HandleFunc("GET /notes", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, store.List())
	})
	mux.HandleFunc("POST /notes", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			Text string `json:"text"`
		}
		r.Body = http.MaxBytesReader(w, r.Body, 16<<10)
		if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
			writeError(w, http.StatusBadRequest, "ожидается JSON вида {\"text\": \"...\"}")
			return
		}
		text := strings.TrimSpace(in.Text)
		if text == "" || utf8.RuneCountInString(text) > MaxTextLen {
			writeError(w, http.StatusBadRequest, "текст заметки — от 1 до 1000 символов")
			return
		}
		n, err := store.Add(text, now())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "не удалось сохранить заметку")
			return
		}
		writeJSON(w, http.StatusCreated, n)
	})
	mux.HandleFunc("GET /notes/{id}", func(w http.ResponseWriter, r *http.Request) {
		id, ok := noteID(w, r)
		if !ok {
			return
		}
		n, err := store.Get(id)
		if errors.Is(err, ErrNotFound) {
			writeError(w, http.StatusNotFound, "заметки нет")
			return
		}
		writeJSON(w, http.StatusOK, n)
	})
	mux.HandleFunc("DELETE /notes/{id}", func(w http.ResponseWriter, r *http.Request) {
		id, ok := noteID(w, r)
		if !ok {
			return
		}
		switch err := store.Delete(id); {
		case errors.Is(err, ErrNotFound):
			writeError(w, http.StatusNotFound, "заметки нет")
		case err != nil:
			writeError(w, http.StatusInternalServerError, "не удалось удалить заметку")
		default:
			w.WriteHeader(http.StatusNoContent)
		}
	})
	return mux
}

func noteID(w http.ResponseWriter, r *http.Request) (int, bool) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil || id < 1 {
		writeError(w, http.StatusBadRequest, "номер заметки — положительное целое")
		return 0, false
	}
	return id, true
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}
