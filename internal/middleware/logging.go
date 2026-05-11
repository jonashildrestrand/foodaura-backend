package middleware

import (
	"log/slog"
	"net/http"
	"time"
)

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (sr *statusRecorder) WriteHeader(code int) {
	sr.status = code
	sr.ResponseWriter.WriteHeader(code)
}

// RequestLogger logs each request with method, path, status, and latency.
// 5xx → Error level; 4xx → Warn; 2xx/3xx → Info.
func RequestLogger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		sr := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sr, r)
		lvl := slog.LevelInfo
		if sr.status >= 500 {
			lvl = slog.LevelError
		} else if sr.status >= 400 {
			lvl = slog.LevelWarn
		}
		slog.Log(r.Context(), lvl, "http",
			"method", r.Method,
			"path", r.URL.Path,
			"status", sr.status,
			"ms", time.Since(start).Milliseconds(),
		)
	})
}
