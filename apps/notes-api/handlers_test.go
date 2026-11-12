package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

var fixedNow = func() time.Time { return time.Date(2026, 11, 12, 7, 0, 0, 0, time.UTC) }

func newServer(t *testing.T) *httptest.Server {
	t.Helper()
	store, err := NewFileStore("")
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(NewHandler(store, fixedNow))
	t.Cleanup(srv.Close)
	return srv
}

func do(t *testing.T, method, url, body string) *http.Response {
	t.Helper()
	req, err := http.NewRequest(method, url, strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { resp.Body.Close() })
	return resp
}

func TestHealthz(t *testing.T) {
	srv := newServer(t)
	if r := do(t, "GET", srv.URL+"/healthz", ""); r.StatusCode != http.StatusOK {
		t.Fatalf("код %d", r.StatusCode)
	}
}

// brokenStore — хранилище, у которого «упала» база.
type brokenStore struct{ *FileStore }

func (brokenStore) Ping(context.Context) error { return errors.New("connection refused") }

func TestReadyz(t *testing.T) {
	srv := newServer(t)
	if r := do(t, "GET", srv.URL+"/readyz", ""); r.StatusCode != http.StatusOK {
		t.Fatalf("исправное хранилище: код %d", r.StatusCode)
	}
	fs, _ := NewFileStore("")
	broken := httptest.NewServer(NewHandler(brokenStore{fs}, fixedNow))
	defer broken.Close()
	if r := do(t, "GET", broken.URL+"/readyz", ""); r.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("база недоступна: код %d, ожидался 503", r.StatusCode)
	}
	if r := do(t, "GET", broken.URL+"/healthz", ""); r.StatusCode != http.StatusOK {
		t.Fatalf("healthz не зависит от базы: код %d", r.StatusCode)
	}
}

func TestVersion(t *testing.T) {
	srv := newServer(t)
	var v map[string]string
	json.NewDecoder(do(t, "GET", srv.URL+"/version", "").Body).Decode(&v)
	if v["version"] == "" || v["commit"] == "" {
		t.Fatalf("нет версии или коммита: %v", v)
	}
}

func TestCreateListGetDelete(t *testing.T) {
	srv := newServer(t)
	r := do(t, "POST", srv.URL+"/notes", `{"text": "  купить молоко  "}`)
	if r.StatusCode != http.StatusCreated {
		t.Fatalf("POST: код %d", r.StatusCode)
	}
	var n Note
	json.NewDecoder(r.Body).Decode(&n)
	if n.ID != 1 || n.Text != "купить молоко" || !n.Created.Equal(fixedNow()) {
		t.Fatalf("заметка %+v", n)
	}
	var list []Note
	json.NewDecoder(do(t, "GET", srv.URL+"/notes", "").Body).Decode(&list)
	if len(list) != 1 {
		t.Fatalf("в списке %d заметок", len(list))
	}
	if r := do(t, "GET", srv.URL+"/notes/1", ""); r.StatusCode != http.StatusOK {
		t.Fatalf("GET: код %d", r.StatusCode)
	}
	if r := do(t, "DELETE", srv.URL+"/notes/1", ""); r.StatusCode != http.StatusNoContent {
		t.Fatalf("DELETE: код %d", r.StatusCode)
	}
	if r := do(t, "GET", srv.URL+"/notes/1", ""); r.StatusCode != http.StatusNotFound {
		t.Fatalf("после удаления: код %d", r.StatusCode)
	}
}

func TestValidation(t *testing.T) {
	srv := newServer(t)
	cases := map[string]string{
		"не JSON":         `текст`,
		"пустой текст":    `{"text": "   "}`,
		"слишком длинный": `{"text": "` + strings.Repeat("я", MaxTextLen+1) + `"}`,
	}
	for name, body := range cases {
		if r := do(t, "POST", srv.URL+"/notes", body); r.StatusCode != http.StatusBadRequest {
			t.Errorf("%s: код %d, ожидался 400", name, r.StatusCode)
		}
	}
	if r := do(t, "GET", srv.URL+"/notes/abc", ""); r.StatusCode != http.StatusBadRequest {
		t.Errorf("номер abc: код %d", r.StatusCode)
	}
	if r := do(t, "DELETE", srv.URL+"/notes/42", ""); r.StatusCode != http.StatusNotFound {
		t.Errorf("удаление несуществующей: код %d", r.StatusCode)
	}
	if r := do(t, "PUT", srv.URL+"/notes", ""); r.StatusCode != http.StatusMethodNotAllowed {
		t.Errorf("PUT: код %d", r.StatusCode)
	}
}
