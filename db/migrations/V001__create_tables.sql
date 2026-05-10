-- V001: Create all Foodaura tables
-- Engine: InnoDB, charset: utf8mb4, collation: utf8mb4_unicode_ci
-- All PKs: CHAR(36) DEFAULT (UUID())
-- All timestamps: DATETIME with DEFAULT CURRENT_TIMESTAMP

SET NAMES utf8mb4;

-- ─── Auth & Sessions ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
  id            CHAR(36)     NOT NULL DEFAULT (UUID()),
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sessions (
  id         CHAR(36)     NOT NULL DEFAULT (UUID()),
  user_id    CHAR(36)     NOT NULL,
  token_hash VARCHAR(255) NOT NULL,
  expires_at DATETIME     NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_sessions_token_hash (token_hash),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Households ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS households (
  id            CHAR(36)     NOT NULL DEFAULT (UUID()),
  name          VARCHAR(255) NOT NULL,
  owner_user_id CHAR(36)     NOT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_households_owner FOREIGN KEY (owner_user_id) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS household_members (
  household_id CHAR(36) NOT NULL,
  user_id      CHAR(36) NOT NULL,
  joined_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (household_id, user_id),
  CONSTRAINT fk_hm_household FOREIGN KEY (household_id) REFERENCES households (id) ON DELETE CASCADE,
  CONSTRAINT fk_hm_user      FOREIGN KEY (user_id)      REFERENCES users (id)      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS household_invitations (
  id                 CHAR(36)     NOT NULL DEFAULT (UUID()),
  household_id       CHAR(36)     NOT NULL,
  invited_by_user_id CHAR(36)     NOT NULL,
  email              VARCHAR(255) NOT NULL,
  token_hash         VARCHAR(255) NOT NULL,
  status             ENUM('pending','accepted','expired') NOT NULL DEFAULT 'pending',
  created_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at         DATETIME     NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_invitations_token_hash (token_hash),
  CONSTRAINT fk_inv_household FOREIGN KEY (household_id)       REFERENCES households (id) ON DELETE CASCADE,
  CONSTRAINT fk_inv_inviter   FOREIGN KEY (invited_by_user_id) REFERENCES users (id)      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Nutritional Profiles & Targets ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS nutritional_profiles (
  id             CHAR(36)          NOT NULL DEFAULT (UUID()),
  user_id        CHAR(36)          NOT NULL,
  biological_sex ENUM('male','female') NOT NULL,
  age            TINYINT UNSIGNED  NOT NULL,
  weight_kg      DECIMAL(5,2)      NOT NULL,
  height_cm      DECIMAL(5,2)      NOT NULL,
  activity_level ENUM('sedentary','light','moderate','active','very_active') NOT NULL,
  goal           ENUM('lose_weight','maintain','build_muscle','eat_better')  NOT NULL,
  updated_at     DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_profiles_user (user_id),
  CONSTRAINT fk_profiles_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS nutritional_targets (
  id            CHAR(36)          NOT NULL DEFAULT (UUID()),
  user_id       CHAR(36)          NOT NULL,
  calories      SMALLINT UNSIGNED NOT NULL,
  protein_g     SMALLINT UNSIGNED NOT NULL,
  carbs_g       SMALLINT UNSIGNED NOT NULL,
  fat_g         SMALLINT UNSIGNED NOT NULL,
  calculated_at DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_targets_user (user_id),
  CONSTRAINT fk_targets_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Recipes ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS recipes (
  id                CHAR(36)          NOT NULL DEFAULT (UUID()),
  title             VARCHAR(255)      NOT NULL,
  description       TEXT,
  cuisine           VARCHAR(100),
  cook_time_minutes SMALLINT UNSIGNED,
  servings_base     TINYINT UNSIGNED  NOT NULL,
  calories          SMALLINT UNSIGNED NOT NULL,
  protein_g         DECIMAL(6,2)      NOT NULL,
  carbs_g           DECIMAL(6,2)      NOT NULL,
  fat_g             DECIMAL(6,2)      NOT NULL,
  created_at        DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS recipe_ingredients (
  id        CHAR(36)         NOT NULL DEFAULT (UUID()),
  recipe_id CHAR(36)         NOT NULL,
  name      VARCHAR(255)     NOT NULL,
  quantity  DECIMAL(8,3)     NOT NULL,
  unit      VARCHAR(50)      NOT NULL,
  category  ENUM('produce','protein','dairy','pantry','frozen','bakery','other') NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_ri_recipe FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Recipe Preferences ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS recipe_preferences (
  id         CHAR(36)               NOT NULL DEFAULT (UUID()),
  user_id    CHAR(36)               NOT NULL,
  recipe_id  CHAR(36)               NOT NULL,
  preference ENUM('like','dislike') NOT NULL,
  created_at DATETIME               NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_rp_user_recipe (user_id, recipe_id),
  CONSTRAINT fk_rp_user   FOREIGN KEY (user_id)   REFERENCES users   (id) ON DELETE CASCADE,
  CONSTRAINT fk_rp_recipe FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ingredient_dislikes (
  id              CHAR(36)     NOT NULL DEFAULT (UUID()),
  user_id         CHAR(36)     NOT NULL,
  ingredient_name VARCHAR(255) NOT NULL,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_id_user_ingredient (user_id, ingredient_name),
  CONSTRAINT fk_id_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Meal Plans ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS meal_plans (
  id              CHAR(36) NOT NULL DEFAULT (UUID()),
  household_id    CHAR(36) NOT NULL,
  week_start_date DATE     NOT NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mp_household_week (household_id, week_start_date),
  CONSTRAINT fk_mp_household FOREIGN KEY (household_id) REFERENCES households (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS meal_slots (
  id           CHAR(36)                                    NOT NULL DEFAULT (UUID()),
  meal_plan_id CHAR(36)                                    NOT NULL,
  day_of_week  TINYINT UNSIGNED                            NOT NULL,  -- 0=Monday … 6=Sunday
  meal_type    ENUM('breakfast','lunch','dinner','snack')  NOT NULL,
  recipe_id    CHAR(36),
  PRIMARY KEY (id),
  UNIQUE KEY uq_ms_plan_day_meal (meal_plan_id, day_of_week, meal_type),
  CONSTRAINT fk_ms_plan   FOREIGN KEY (meal_plan_id) REFERENCES meal_plans (id) ON DELETE CASCADE,
  CONSTRAINT fk_ms_recipe FOREIGN KEY (recipe_id)    REFERENCES recipes    (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS meal_slot_participants (
  meal_slot_id CHAR(36) NOT NULL,
  user_id      CHAR(36) NOT NULL,
  PRIMARY KEY (meal_slot_id, user_id),
  CONSTRAINT fk_msp_slot FOREIGN KEY (meal_slot_id) REFERENCES meal_slots (id) ON DELETE CASCADE,
  CONSTRAINT fk_msp_user FOREIGN KEY (user_id)      REFERENCES users      (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Shopping List ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS shopping_list_items (
  id              CHAR(36)    NOT NULL DEFAULT (UUID()),
  meal_plan_id    CHAR(36)    NOT NULL,
  ingredient_name VARCHAR(255) NOT NULL,
  total_quantity  DECIMAL(10,3) NOT NULL,
  unit            VARCHAR(50)  NOT NULL,
  category        ENUM('produce','protein','dairy','pantry','frozen','bakery','other') NOT NULL,
  is_checked      BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_sli_plan FOREIGN KEY (meal_plan_id) REFERENCES meal_plans (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Notifications ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS notifications (
  id             CHAR(36)  NOT NULL DEFAULT (UUID()),
  user_id        CHAR(36)  NOT NULL,
  type           ENUM(
                   'household_invitation_received',
                   'household_invitation_accepted',
                   'household_member_left',
                   'household_member_removed',
                   'meal_plan_ready'
                 )         NOT NULL,
  title          VARCHAR(255) NOT NULL,
  body           TEXT         NOT NULL,
  reference_type VARCHAR(50),
  reference_id   CHAR(36),
  is_read        BOOLEAN   NOT NULL DEFAULT FALSE,
  read_at        DATETIME,
  created_at     DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS notification_dispatches (
  id              CHAR(36)                     NOT NULL DEFAULT (UUID()),
  notification_id CHAR(36)                     NOT NULL,
  channel         ENUM('email','sms','push')   NOT NULL,
  dispatched_at   DATETIME                     NOT NULL,
  status          ENUM('sent','failed')        NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_nd_notification FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
