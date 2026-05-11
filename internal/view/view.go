package view

import (
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"path/filepath"
	"strings"
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

// Render parses _layout + partials + the page template, then executes "_layout".
// pageFile is relative to templates/pages/, e.g. "login.gohtml".
// For onboarding pages, it also includes pages/onboarding/_steps.gohtml.
func (r *Renderer) Render(w http.ResponseWriter, pageFile string, data any) error {
	files := make([]string, 0, len(partials)+2)

	// Always include the layout and shared partials.
	for _, p := range partials {
		files = append(files, filepath.Join(r.dir, p))
	}

	// The page itself.
	files = append(files, filepath.Join(r.dir, "pages", pageFile))

	// For onboarding, also include the step partials.
	if strings.HasPrefix(pageFile, "onboarding") {
		stepsFile := filepath.Join(r.dir, "pages", "onboarding", "_steps.gohtml")
		files = append(files, stepsFile)
	}

	// Parse from the first file so the template name is derived from _layout.gohtml.
	tmpl, err := template.New(filepath.Base(files[0])).Funcs(funcMap).ParseFiles(files...)
	if err != nil {
		return fmt.Errorf("view.Render parse %q: %w", pageFile, err)
	}

	// Parse the inline _toast definition (overrides any definition in partials).
	tmpl, err = tmpl.Parse(toastTmpl)
	if err != nil {
		return fmt.Errorf("view.Render parse toast: %w", err)
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := tmpl.ExecuteTemplate(w, "_layout", data); err != nil {
		return fmt.Errorf("view.Render execute %q: %w", pageFile, err)
	}
	return nil
}
