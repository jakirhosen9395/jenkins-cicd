# ---------- builder stage ----------
FROM golang:1.22-bookworm AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" \
    -o /out/app .

# ---------- runtime stage ----------
FROM gcr.io/distroless/static-debian12
WORKDIR /app
COPY --from=builder /out/app /app/app
COPY index.html /app/index.html
EXPOSE 9000
USER nonroot:nonroot
ENV HOST=0.0.0.0
ENV PORT=9000
ENTRYPOINT ["/app/app"]