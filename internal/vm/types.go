// Package vm holds plain Go structs that templates render against.
//
// One file per page, named <Page>VM. No methods, no validation, no business
// logic — these are passive carriers of data scanned out of stored procedures.
//
// Every VM embeds BaseVM so _layout.gohtml can render the chrome consistently.
package vm

import "html/template"

// ───────────────────────── chrome ─────────────────────────

type BaseVM struct {
	Chrome  ChromeVM
	Sidebar SidebarVM
	Toast   *ToastVM // nil when absent
}

type ChromeVM struct {
	ShowSidebar bool
}

type SidebarVM struct {
	ActiveRoute  string // "plan" | "discover" | "shopping" | "household" | "notifications" | "settings"
	UnreadNotifs int
	CurrentUser  MemberVM
}

type ToastVM struct {
	Message string
}

// ───────────────────────── primitives ─────────────────────

type MemberVM struct {
	Initials string
	Name     string
	Goal     string
	Tint     string // "p" | "s" — derived from join order in sp_household_get
}

type TagVM struct {
	Tone  string // "neutral" | "brand" | "affirm"
	Label string
}

type ActionVM struct {
	Label      string
	Icon       string
	Variant    string // "primary" | "secondary" | "ghost"
	Href       string
	FormAction string
	FormMethod string // "post" | "get" — used when FormAction is set
}

type TopbarVM struct {
	Eyebrow string
	Title   string
	Sub     string
	Actions []ActionVM
}

type NutritionVM struct {
	Protein int // grams
	Carbs   int
	Fat     int
	Kcal    int
	Dense   bool
}

type SlotVM struct {
	ID        int64
	Meal      string // "Brk" | "Lun" | "Din" | "Snk"
	Name      string
	Kcal      int
	Tone      string // "peach" | "sage" | "oat"
	RecipeURL string
	Empty     bool   // when true, render _empty_slot
	AddURL    string // used when Empty
}

type DayColumnVM struct {
	Day       string      // "Mon"
	Date      string      // "12"
	Slots     []SlotVM
	DayTotal  NutritionVM // sum across all assigned slots for the day
}

type RecipeCardVM struct {
	ID             int64
	Name           string
	Tone           string
	MinutesHandsOn int
	Servings       int
	Tags           []TagVM
}

// ───────────────────────── pages ──────────────────────────

type PlanVM struct {
	BaseVM
	Topbar TopbarVM
	Days   []DayColumnVM
	Stats  struct {
		MealsPlanned int
		EmptySlots   int
		MembersIn    int
	}
}

type RecipeVM struct {
	BaseVM
	Topbar    TopbarVM
	ID        int64
	Name      string
	Tone      string
	Hero      string // image URL or empty for placeholder
	Servings  int
	Minutes   int
	Members   []MemberVM
	Tags      []TagVM
	Nutrition NutritionVM
	Steps     []string
	// Quantities arrive already scaled — sp_recipe_scale runs in MariaDB.
	Ingredients []struct {
		Quantity string
		Unit     string
		Name     string
	}
}

type ShoppingVM struct {
	BaseVM
	Topbar     TopbarVM
	WeekRange  string
	Categories []struct {
		Name  string
		Items []struct {
			ID       int64
			Quantity string
			Unit     string
			Name     string
			Bought   bool
		}
	}
}

type HouseholdVM struct {
	BaseVM
	Topbar   TopbarVM
	Name     string
	Members  []MemberVM
	Schedule struct {
		Days []string
		Rows []ScheduleRowVM // one per member
	}
	InviteOpen bool // server-rendered fallback when ?invite=1
}

type ScheduleRowVM struct {
	MemberShort string // "Sam"
	In          []bool // per-day flags
}

type DiscoverVM struct {
	BaseVM
	Topbar  TopbarVM
	Search  string // current search term — echoed back into the input
	Filters []struct {
		Label  string
		Value  string
		Active bool
	}
	Recipes []RecipeCardVM
}

type SettingsVM struct {
	BaseVM
	Topbar   TopbarVM
	Sections []SettingsSectionVM
}

type SettingsSectionVM struct {
	ID    string
	Title string
	Sub   string
	Icon  string
	Rows  []SettingsRowVM
}

type SettingsRowVM struct {
	Label   string
	Hint    string
	Control SettingsControlVM
}

type SettingsControlVM struct {
	Kind    string   // "text" | "toggle" | "seg" | "button"
	Name    string
	Value   string
	Options []string // for "seg"
	Action  ActionVM // for "button"
}

type NotifsVM struct {
	BaseVM
	Topbar TopbarVM
	Today  []NotifVM
	Week   []NotifVM
}

type NotifVM struct {
	ID     int64
	Tint   string // "p" | "sage" | "oat" | "neutral"
	Icon   string
	Title  string
	Body   string
	Time   string
	Unread bool
	CTA    *ActionVM
}

type LoginVM struct {
	BaseVM
	Error string // non-empty when login failed
}

type LandingVM struct {
	BaseVM
}

type ErrorVM struct {
	BaseVM
	Code    int
	Title   string
	Message string
}

type GoalOption struct {
	Value string `json:"value"`
	Label string `json:"label"`
	Icon  string `json:"icon"`
}

type DietTypeOption struct {
	Value string `json:"value"`
	Label string `json:"label"`
}

type OnboardingVM struct {
	BaseVM
	Goals       []GoalOption
	DietTypes   []DietTypeOption
	GoalsJS     template.JS
	DietTypesJS template.JS
}

