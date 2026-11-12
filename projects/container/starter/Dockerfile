# syntax=docker/dockerfile:1
# Dockerfile для notes-api. Требования (подробно — в README проекта и в рубрике приложения):
#
#  1. Две стадии. Сборка — официальный образ golang с конкретной версией (не latest):
#     go vet, go test и статический бинарник: CGO_ENABLED=0 go build -trimpath -ldflags "-s -w ...".
#  2. Версия и коммит передаются аргументами сборки VERSION и COMMIT
#     и попадают в бинарник через -ldflags "-X main.version=… -X main.commit=…".
#  3. Порядок слоёв: сначала go.mod, go.sum и go mod download, потом исходники — тогда зависимости кешируются.
#  4. Запуск — gcr.io/distroless/static-debian13:nonroot: только бинарник, без оболочки, не от root.
#  5. Каталог /data для заметок (DATA_DIR=/data) принадлежит пользователю nonroot (uid 65532),
#     иначе сервис не сможет писать в именованный том.
#  6. HEALTHCHECK: в distroless нет curl, но у сервиса есть режим /notes-api -healthcheck.
#  7. EXPOSE 8080, ENTRYPOINT в форме JSON-массива.
#
# TODO: напишите Dockerfile по этим требованиям. Пока его нет, docker build завершится ошибкой.
