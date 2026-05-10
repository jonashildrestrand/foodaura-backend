package main

import (
	"log"
	"net/http"

	"github.com/foodaura/backend/internal/config"
	"github.com/foodaura/backend/internal/controller"
	appdb "github.com/foodaura/backend/internal/db"
	"github.com/foodaura/backend/internal/middleware"
	"github.com/foodaura/backend/internal/view"
	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
)

func main() {
	cfg := config.Load()

	db, err := appdb.Open(cfg)
	if err != nil {
		log.Fatalf("db.Open: %v", err)
	}
	if err := db.Ping(); err != nil {
		log.Printf("warning: db ping failed: %v", err)
	}

	renderer := view.NewRenderer("templates")

	r := chi.NewRouter()
	r.Use(chimw.Logger)
	r.Use(chimw.Recoverer)

	// Static files.
	r.Handle("/static/*", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))

	// Public routes (no auth).
	r.Get("/", func(w http.ResponseWriter, req *http.Request) {
		http.Redirect(w, req, "/login", http.StatusSeeOther)
	})
	r.Get("/login", controller.GetLogin(renderer))
	r.Post("/login", controller.PostLogin(db, renderer))

	// Onboarding step 0 is public (registration).
	r.Get("/onboarding/0", controller.GetOnboarding0(renderer))
	r.Post("/onboarding/0", controller.PostOnboarding0(db))

	// Onboarding steps 1-4 require auth (user already has a session after step 0).
	r.Group(func(r chi.Router) {
		r.Use(middleware.Auth(db))

		r.Get("/onboarding/1", controller.GetOnboarding1(db, renderer))
		r.Post("/onboarding/1", controller.PostOnboarding1(db))
		r.Get("/onboarding/2", controller.GetOnboarding2(db, renderer))
		r.Post("/onboarding/2", controller.PostOnboarding2(db))
		r.Get("/onboarding/3", controller.GetOnboarding3(db, renderer))
		r.Post("/onboarding/3", controller.PostOnboarding3(db))
		r.Get("/onboarding/4", controller.GetOnboarding4(db, renderer))
		r.Post("/onboarding/4", controller.PostOnboarding4())
	})

	// Invitation join link (requires auth — user must be registered first).
	r.Group(func(r chi.Router) {
		r.Use(middleware.Auth(db))
		r.Get("/household/join/{token}", controller.GetJoinHousehold(db))
	})

	// Authenticated application routes.
	r.Group(func(r chi.Router) {
		r.Use(middleware.Auth(db))

		r.Post("/logout", controller.PostLogout(db))

		// Meal plan.
		r.Get("/plan", controller.GetPlan(db, renderer))
		r.Post("/plan/slot/{slotID}/assign", controller.PostAssignRecipe(db))
		r.Post("/plan/slot/{slotID}/clear", controller.PostClearSlot(db))

		// Discover / recipes.
		r.Get("/discover", controller.GetDiscover(db, renderer))
		r.Get("/recipes/{id}", controller.GetRecipe(db, renderer))
		r.Post("/recipes/{id}/preference", controller.PostRecipePreference(db))

		// Shopping list.
		r.Get("/shoppinglist", controller.GetShopping(db, renderer))
		r.Get("/shoppinglist/{planID}", controller.GetShopping(db, renderer))
		r.Post("/shoppinglist/{planID}/item/{itemID}/toggle", controller.PostToggleItem(db))

		// Household.
		r.Get("/household", controller.GetHousehold(db, renderer))
		r.Post("/household/invite", controller.PostInvite(db))
		r.Post("/household/leave", controller.PostLeaveHousehold(db))
		r.Post("/household/remove", controller.PostRemoveMember(db))

		// Notifications.
		r.Get("/notifications", controller.GetNotifications(db, renderer))
		r.Post("/notifications/mark-all-read", controller.PostMarkAllRead(db))
		r.Post("/notifications/{id}/read", controller.PostMarkRead(db))

		// Profile.
		r.Get("/profile/setup", controller.GetProfileSetup(db, renderer))
		r.Post("/profile/setup", controller.PostProfileSetup(db, renderer))
		r.Get("/profile/edit", controller.GetProfileEdit(db, renderer))
		r.Post("/profile/edit", controller.PostProfileEdit(db, renderer))
	})

	addr := ":" + cfg.Port
	log.Printf("foodaura-backend listening on %s", addr)
	if err := http.ListenAndServe(addr, r); err != nil {
		log.Fatalf("ListenAndServe: %v", err)
	}
}
