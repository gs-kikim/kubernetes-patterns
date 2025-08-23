# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY main.go .
COPY go.mod .

RUN go build -o server main.go

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates curl

WORKDIR /app
COPY --from=builder /app/server .

# 헬스체크 추가
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080

ENTRYPOINT ["./server"]