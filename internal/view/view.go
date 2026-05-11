package view

import (
	"bytes"
	"encoding/json"
	"fmt"
	"html/template"
	"log/slog"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/foodaura/backend/internal/vm"
)

var funcMap = template.FuncMap{
	"inc":   func(i int) int { return i + 1 },
	"slice": func(v ...string) []string { return v },
	// toJS marshals v to JSON and returns it as template.JS so html/template
	// embeds it verbatim inside <script> tags without HTML-escaping.
	"toJS": func(v any) (template.JS, error) {
		b, err := json.Marshal(v)
		if err != nil {
			return "", err
		}
		return template.JS(b), nil
	},
}

// toastTmpl is defined inline so _layout.gohtml never errors when .Toast is nil.
const toastTmpl = `{{ define "_toast" }}<div class="fa-toast">{{ .Message }}</div>{{ end }}`

// Renderer holds the template directory path and always-included partials.
type Renderer struct {
	dir string
}

// NewRenderer creates a Renderer rooted at templateDir.
func NewRenderer(templateDir string) *Renderer {
	return &Renderer{dir: templateDir}
}

// partials lists the partials that are always included when rendering any page.
var partials = []string{
	"_layout.gohtml",
	"partials/_sidebar.gohtml",
	"partials/_topbar.gohtml",
	"partials/_recipe_card.gohtml",
	"partials/_slot_card.gohtml",
	"partials/_member_chip.gohtml",
	"partials/_nutrition_bar.gohtml",
	"partials/_invite_modal.gohtml",
}

var errorTitles = map[int]string{
	http.StatusNotFound:            "Page not found",
	http.StatusInternalServerError: "Something went wrong",
	http.StatusForbidden:           "Access denied",
	http.StatusUnauthorized:        "Not authorised",
}

var errorMessages = map[int]string{
	http.StatusNotFound:            "The page you're looking for doesn't exist.",
	http.StatusInternalServerError: "An unexpected error occurred. Please try again in a moment.",
	http.StatusForbidden:           "You don't have permission to view this page.",
	http.StatusUnauthorized:        "You need to sign in to view this page.",
}

// RenderError renders the error page template with the given HTTP status code.
// Falls back to plain-text http.Error if template rendering itself fails.
func (r *Renderer) RenderError(w http.ResponseWriter, status int) {
	title, ok := errorTitles[status]
	if !ok {
		title = http.StatusText(status)
	}
	msg, ok := errorMessages[status]
	if !ok {
		msg = "An error occurred."
	}
	data := vm.ErrorVM{
		BaseVM:  vm.BaseVM{Chrome: vm.ChromeVM{ShowSidebar: false}},
		Code:    status,
		Title:   title,
		Message: msg,
	}

	buf, err := r.renderBuffer("error.gohtml", data)
	if err != nil {
		slog.Error("error page render failed", "status", status, "error", err)
		http.Error(w, http.StatusText(status), status)
		return
	}

	// Headers are set AFTER the buffer is ready so a render failure can still
	// send a clean plain-text 500 via http.Error above.
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	buf.WriteTo(w)
}

// renderBuffer parses and executes the page template into a buffer without
// touching the ResponseWriter — callers decide which status to send.
func (r *Renderer) renderBuffer(pageFile string, data any) (*bytes.Buffer, error) {
	files := make([]string, 0, len(partials)+2)

	for _, p := range partials {
		files = append(files, filepath.Join(r.dir, p))
	}
	files = append(files, filepath.Join(r.dir, "pages", pageFile))

	if strings.HasPrefix(pageFile, "onboarding") {
		files = append(files, filepath.Join(r.dir, "pages", "onboarding", "_steps.gohtml"))
	}

	tmpl, err := template.New(filepath.Base(files[0])).Funcs(funcMap).ParseFiles(files...)
	if err != nil {
		slog.Error("template parse failed", "page", pageFile, "error", err)
		return nil, fmt.Errorf("view.Render parse %q: %w", pageFile, err)
	}
	tmpl, err = tmpl.Parse(toastTmpl)
	if err != nil {
		slog.Error("template parse toast failed", "error", err)
		return nil, fmt.Errorf("view.Render parse toast: %w", err)
	}

	var buf bytes.Buffer
	if err := tmpl.ExecuteTemplate(&buf, "_layout", data); err != nil {
		slog.Error("template execute failed", "page", pageFile, "error", err)
		return nil, fmt.Errorf("view.Render execute %q: %w", pageFile, err)
	}
	return &buf, nil
}

// Render parses _layout + partials + the page template, executes into a buffer,
// then writes the result to w. Buffering ensures a template execution error
// never produces a partial response — the caller can still send a proper error.
func (r *Renderer) Render(w http.ResponseWriter, pageFile string, data any) error {
	buf, err := r.renderBuffer(pageFile, data)
	if err != nil {
		return err
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, err = buf.WriteTo(w)
	return err
}
