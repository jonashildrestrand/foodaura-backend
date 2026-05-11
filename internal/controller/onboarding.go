package controller

import (
	"net/http"

	"github.com/foodaura/backend/internal/view"
	"github.com/foodaura/backend/internal/vm"
)

func GetOnboarding(v *view.Renderer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		data := vm.BaseVM{
			Chrome: vm.ChromeVM{ShowSidebar: false},
		}
		if err := v.Render(w, "onboarding.gohtml", data); err != nil {
			http.Error(w, "render error", http.StatusInternalServerError)
		}
	}
}
