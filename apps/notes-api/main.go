// notes-api — учебный сервис заметок для проекта «Сервис в контейнере с пайплайном».
//
// Настройки — переменные окружения:
//
//	PORT      порт HTTP, по умолчанию 8080
//	DATA_DIR  каталог для notes.json; пусто — заметки только в памяти
//
// Флаг -healthcheck: запрос к http://127.0.0.1:PORT/healthz и выход с кодом 0 или 1.
// Нужен для HEALTHCHECK в образе без оболочки и curl (distroless).
package main

import (
	"context"
	"errors"
	"flag"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	healthcheck := flag.Bool("healthcheck", false, "проверить /healthz запущенного сервиса и выйти")
	flag.Parse()
	port := env("PORT", "8080")
	if *healthcheck {
		os.Exit(probe("http://127.0.0.1:" + port + "/healthz"))
	}

	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	store, err := NewStore(os.Getenv("DATA_DIR"))
	if err != nil {
		log.Error("не удалось открыть хранилище", "err", err)
		os.Exit(1)
	}
	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           NewHandler(store, time.Now),
		ReadHeaderTimeout: 5 * time.Second,
	}

	// SIGTERM присылает docker stop и Kubernetes: дожидаемся текущих запросов и выходим.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		log.Info("сервис запущен", "addr", srv.Addr, "version", version, "commit", commit)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("сервер остановлен с ошибкой", "err", err)
			os.Exit(1)
		}
	}()
	<-ctx.Done()
	shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdown); err != nil {
		log.Error("остановка не уложилась в таймаут", "err", err)
		os.Exit(1)
	}
	log.Info("сервис остановлен")
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func probe(url string) int {
	client := http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return 1
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
