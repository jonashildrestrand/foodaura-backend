CREATE TABLE `households` (
    `id`         VARCHAR(36)  NOT NULL,
    `name`       VARCHAR(255) NOT NULL,
    `created_at` VARCHAR(30)  NOT NULL DEFAULT (NOW()),
    CONSTRAINT `households_id` PRIMARY KEY (`id`)
);

CREATE TABLE `profiles` (
    `id`            VARCHAR(36)  NOT NULL,
    `household_id`  VARCHAR(36)  NOT NULL,
    `name`          VARCHAR(255) NOT NULL,
    `email`         VARCHAR(255),
    `password_hash` VARCHAR(255),
    `pin`           VARCHAR(255),
    `avatar_url`    VARCHAR(512),
    `unit_system`   VARCHAR(20)  NOT NULL DEFAULT 'metric',
    `created_at`    VARCHAR(30)  NOT NULL DEFAULT (NOW()),
    CONSTRAINT `profiles_id`           PRIMARY KEY (`id`),
    CONSTRAINT `profiles_email_unique` UNIQUE (`email`),
    CONSTRAINT `profiles_household_id_fk` FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON DELETE CASCADE,
    INDEX `profiles_household_id_idx` (`household_id`)
);

CREATE TABLE `recipes` (
    `id`               VARCHAR(36)  NOT NULL,
    `name`             VARCHAR(255) NOT NULL,
    `slot`             VARCHAR(10)  NOT NULL,
    `servings`         INT          NOT NULL DEFAULT 2,
    `prep_time_min`    INT,
    `cook_time_min`    INT,
    `kcal`             INT          NOT NULL,
    `protein_g`        DOUBLE       NOT NULL,
    `carbs_g`          DOUBLE       NOT NULL,
    `fat_g`            DOUBLE       NOT NULL,
    `saturated_fat_g`  DOUBLE,
    `fiber_g`          DOUBLE,
    `sugar_g`          DOUBLE,
    `sodium_mg`        DOUBLE,
    `ingredients`      TEXT         NOT NULL,
    `steps`            TEXT         NOT NULL,
    `tags`             TEXT,
    `source`           VARCHAR(50),
    `household_id`     VARCHAR(36),
    `created_at`       VARCHAR(30)  NOT NULL DEFAULT (NOW()),
    CONSTRAINT `recipes_id` PRIMARY KEY (`id`),
    CONSTRAINT `recipes_household_id_fk` FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON DELETE SET NULL,
    INDEX `recipes_slot_idx` (`slot`)
);

CREATE TABLE `meal_plans` (
    `id`           VARCHAR(36) NOT NULL,
    `household_id` VARCHAR(36) NOT NULL,
    `week_start`   VARCHAR(10) NOT NULL,
    `created_at`   VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `meal_plans_id`                  PRIMARY KEY (`id`),
    CONSTRAINT `meal_plans_household_week_uniq` UNIQUE (`household_id`, `week_start`),
    CONSTRAINT `meal_plans_household_id_fk`     FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON DELETE CASCADE,
    INDEX `meal_plans_household_id_idx` (`household_id`)
);

CREATE TABLE `meal_plan_entries` (
    `id`               VARCHAR(36)  NOT NULL,
    `plan_id`          VARCHAR(36)  NOT NULL,
    `day`              INT          NOT NULL,
    `slot`             VARCHAR(10)  NOT NULL,
    `recipe_id`        VARCHAR(36)  NOT NULL,
    `profile_portions` TEXT,
    `is_leftover`      BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT `meal_plan_entries_id`  PRIMARY KEY (`id`),
    CONSTRAINT `plan_day_slot_idx`     UNIQUE (`plan_id`, `day`, `slot`),
    CONSTRAINT `mpe_plan_id_fk`        FOREIGN KEY (`plan_id`)   REFERENCES `meal_plans`(`id`) ON DELETE CASCADE,
    CONSTRAINT `mpe_recipe_id_fk`      FOREIGN KEY (`recipe_id`) REFERENCES `recipes`(`id`)    ON DELETE NO ACTION
);

CREATE TABLE `shopping_list_items` (
    `id`                    VARCHAR(36)  NOT NULL,
    `plan_id`               VARCHAR(36)  NOT NULL,
    `name`                  VARCHAR(255) NOT NULL,
    `quantity`              VARCHAR(50)  NOT NULL,
    `category`              VARCHAR(50)  NOT NULL,
    `for_profile_id`        VARCHAR(36),
    `checked`               BOOLEAN      NOT NULL DEFAULT FALSE,
    `checked_by_profile_id` VARCHAR(36),
    CONSTRAINT `shopping_list_items_id`      PRIMARY KEY (`id`),
    CONSTRAINT `sli_plan_id_fk`              FOREIGN KEY (`plan_id`)               REFERENCES `meal_plans`(`id`) ON DELETE CASCADE,
    CONSTRAINT `sli_for_profile_id_fk`       FOREIGN KEY (`for_profile_id`)        REFERENCES `profiles`(`id`)   ON DELETE SET NULL,
    CONSTRAINT `sli_checked_by_profile_id_fk` FOREIGN KEY (`checked_by_profile_id`) REFERENCES `profiles`(`id`) ON DELETE SET NULL,
    INDEX `shopping_list_items_plan_id_idx` (`plan_id`)
);

CREATE TABLE `sessions` (
    `id`                VARCHAR(36) NOT NULL,
    `household_id`      VARCHAR(36) NOT NULL,
    `active_profile_id` VARCHAR(36) NOT NULL,
    `expires_at`        VARCHAR(30) NOT NULL,
    `created_at`        VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `sessions_id` PRIMARY KEY (`id`),
    CONSTRAINT `sessions_household_id_fk`      FOREIGN KEY (`household_id`)      REFERENCES `households`(`id`) ON DELETE CASCADE,
    CONSTRAINT `sessions_active_profile_id_fk` FOREIGN KEY (`active_profile_id`) REFERENCES `profiles`(`id`)  ON DELETE NO ACTION
);

CREATE TABLE `invite_tokens` (
    `id`                    VARCHAR(36)  NOT NULL,
    `household_id`          VARCHAR(36)  NOT NULL,
    `invited_by_profile_id` VARCHAR(36)  NOT NULL,
    `email`                 VARCHAR(255) NOT NULL,
    `token`                 VARCHAR(255) NOT NULL,
    `expires_at`            VARCHAR(30)  NOT NULL,
    `used_at`               VARCHAR(30),
    `created_at`            VARCHAR(30)  NOT NULL DEFAULT (NOW()),
    CONSTRAINT `invite_tokens_id`           PRIMARY KEY (`id`),
    CONSTRAINT `invite_tokens_token_unique` UNIQUE (`token`),
    CONSTRAINT `invite_tokens_household_id_fk`          FOREIGN KEY (`household_id`)          REFERENCES `households`(`id`) ON DELETE CASCADE,
    CONSTRAINT `invite_tokens_invited_by_profile_id_fk` FOREIGN KEY (`invited_by_profile_id`) REFERENCES `profiles`(`id`)  ON DELETE CASCADE
);

CREATE TABLE `reset_tokens` (
    `id`         VARCHAR(36)  NOT NULL,
    `profile_id` VARCHAR(36)  NOT NULL,
    `token`      VARCHAR(255) NOT NULL,
    `expires_at` VARCHAR(30)  NOT NULL,
    `used_at`    VARCHAR(30),
    `created_at` VARCHAR(30)  NOT NULL DEFAULT (NOW()),
    CONSTRAINT `reset_tokens_id`           PRIMARY KEY (`id`),
    CONSTRAINT `reset_tokens_token_unique` UNIQUE (`token`),
    CONSTRAINT `reset_tokens_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE
);

CREATE TABLE `auth_rate_limits` (
    `id`           VARCHAR(36) NOT NULL,
    `ip`           VARCHAR(64) NOT NULL,
    `route`        VARCHAR(40) NOT NULL,
    `attempted_at` VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `auth_rate_limits_id` PRIMARY KEY (`id`),
    INDEX `auth_rate_limits_ip_route_idx` (`ip`, `route`, `attempted_at`)
);

CREATE TABLE `push_subscriptions` (
    `id`         VARCHAR(36) NOT NULL,
    `profile_id` VARCHAR(36) NOT NULL,
    `endpoint`   TEXT        NOT NULL,
    `p256dh`     VARCHAR(255) NOT NULL,
    `auth`       VARCHAR(255) NOT NULL,
    `created_at` VARCHAR(30)  NOT NULL DEFAULT (NOW()),
    CONSTRAINT `push_subscriptions_id` PRIMARY KEY (`id`),
    CONSTRAINT `push_subscriptions_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE,
    INDEX `push_subscriptions_profile_id_idx` (`profile_id`)
);

CREATE TABLE `habits` (
    `id`         VARCHAR(36)  NOT NULL,
    `profile_id` VARCHAR(36)  NOT NULL,
    `name`       VARCHAR(255) NOT NULL,
    `active`     BOOLEAN      NOT NULL DEFAULT TRUE,
    `created_at` VARCHAR(30)  NOT NULL DEFAULT (NOW()),
    CONSTRAINT `habits_id` PRIMARY KEY (`id`),
    CONSTRAINT `habits_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE,
    INDEX `habits_profile_id_idx` (`profile_id`)
);

CREATE TABLE `habit_completions` (
    `id`        VARCHAR(36) NOT NULL,
    `habit_id`  VARCHAR(36) NOT NULL,
    `date`      VARCHAR(10) NOT NULL,
    `completed` BOOLEAN     NOT NULL DEFAULT FALSE,
    CONSTRAINT `habit_completions_id`  PRIMARY KEY (`id`),
    CONSTRAINT `habit_completion_idx`  UNIQUE (`habit_id`, `date`),
    CONSTRAINT `habit_completions_habit_id_fk` FOREIGN KEY (`habit_id`) REFERENCES `habits`(`id`) ON DELETE CASCADE
);

CREATE TABLE `daily_checkins` (
    `id`           VARCHAR(36) NOT NULL,
    `profile_id`   VARCHAR(36) NOT NULL,
    `date`         VARCHAR(10) NOT NULL,
    `adherence`    VARCHAR(10),
    `snacking`     VARCHAR(5),
    `energy`       INT,
    `habits`       TEXT,
    `notes`        TEXT,
    `completed_at` VARCHAR(30),
    `updated_at`   VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `daily_checkins_id`           PRIMARY KEY (`id`),
    CONSTRAINT `checkin_profile_date_idx`    UNIQUE (`profile_id`, `date`),
    CONSTRAINT `daily_checkins_energy_range` CHECK (`energy` IS NULL OR (`energy` >= 1 AND `energy` <= 5)),
    CONSTRAINT `daily_checkins_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE
);

CREATE TABLE `weekly_checkins` (
    `id`           VARCHAR(36) NOT NULL,
    `profile_id`   VARCHAR(36) NOT NULL,
    `week_start`   VARCHAR(10) NOT NULL,
    `weight`       DOUBLE,
    `wins`         TEXT,
    `struggles`    TEXT,
    `prep_flags`   TEXT,
    `completed_at` VARCHAR(30),
    `updated_at`   VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `weekly_checkins_id`           PRIMARY KEY (`id`),
    CONSTRAINT `weekly_profile_week_idx`      UNIQUE (`profile_id`, `week_start`),
    CONSTRAINT `weekly_checkins_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE
);

CREATE TABLE `recipe_ratings` (
    `id`               VARCHAR(36) NOT NULL,
    `weekly_checkin_id` VARCHAR(36) NOT NULL,
    `recipe_id`        VARCHAR(36) NOT NULL,
    `stars`            INT,
    `make_again`       BOOLEAN,
    `never_again`      BOOLEAN,
    CONSTRAINT `recipe_ratings_id`              PRIMARY KEY (`id`),
    CONSTRAINT `rating_checkin_recipe_idx`      UNIQUE (`weekly_checkin_id`, `recipe_id`),
    CONSTRAINT `recipe_ratings_stars_range`     CHECK (`stars` IS NULL OR (`stars` >= 1 AND `stars` <= 5)),
    CONSTRAINT `recipe_ratings_checkin_id_fk`  FOREIGN KEY (`weekly_checkin_id`) REFERENCES `weekly_checkins`(`id`) ON DELETE CASCADE,
    CONSTRAINT `recipe_ratings_recipe_id_fk`   FOREIGN KEY (`recipe_id`)         REFERENCES `recipes`(`id`)        ON DELETE NO ACTION
);

CREATE TABLE `person_recipe_ratings` (
    `profile_id` VARCHAR(36) NOT NULL,
    `recipe_id`  VARCHAR(36) NOT NULL,
    `rating`     VARCHAR(20) NOT NULL,
    `updated_at` VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `person_recipe_rating_idx`       UNIQUE (`profile_id`, `recipe_id`),
    CONSTRAINT `prr_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE,
    CONSTRAINT `prr_recipe_id_fk`  FOREIGN KEY (`recipe_id`)  REFERENCES `recipes`(`id`)  ON DELETE CASCADE
);

CREATE TABLE `recipe_exclusions` (
    `profile_id` VARCHAR(36) NOT NULL,
    `recipe_id`  VARCHAR(36) NOT NULL,
    `created_at` VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `exclusion_idx` UNIQUE (`profile_id`, `recipe_id`),
    CONSTRAINT `re_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE,
    CONSTRAINT `re_recipe_id_fk`  FOREIGN KEY (`recipe_id`)  REFERENCES `recipes`(`id`)  ON DELETE CASCADE
);

CREATE TABLE `nutrition_profiles` (
    `profile_id`          VARCHAR(36) NOT NULL,
    `activity_level`      VARCHAR(20) NOT NULL DEFAULT 'moderately_active',
    `dietary_approach`    VARCHAR(20),
    `meal_frequency`      INT          DEFAULT 3,
    `includes_snacks`     BOOLEAN      DEFAULT TRUE,
    `eating_window_start` VARCHAR(5),
    `eating_window_end`   VARCHAR(5),
    `waist_cm`            DOUBLE,
    `body_fat_pct`        DOUBLE,
    `supplements`         TEXT,
    `hydration_target_ml` INT          DEFAULT 2000,
    `notes`               TEXT,
    `updated_at`          VARCHAR(30)  NOT NULL DEFAULT (NOW()),
    CONSTRAINT `nutrition_profiles_profile_id` PRIMARY KEY (`profile_id`),
    CONSTRAINT `np_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE
);

CREATE TABLE `profile_body` (
    `profile_id` VARCHAR(36) NOT NULL,
    `height_cm`  DOUBLE,
    `weight_kg`  DOUBLE,
    `age`        INT,
    `sex`        VARCHAR(10),
    `updated_at` VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `profile_body_profile_id` PRIMARY KEY (`profile_id`),
    CONSTRAINT `pb_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE
);

CREATE TABLE `profile_goals` (
    `profile_id`            VARCHAR(36) NOT NULL,
    `target_weight_kg`      DOUBLE,
    `goals`                 TEXT,
    `calorie_target`        INT,
    `protein_target_g`      INT,
    `carbs_target_g`        INT,
    `fat_target_g`          INT,
    `saturated_fat_target_g` INT,
    `fiber_target_g`        INT,
    `sugar_limit_g`         INT,
    `sodium_limit_mg`       INT,
    `updated_at`            VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `profile_goals_profile_id` PRIMARY KEY (`profile_id`),
    CONSTRAINT `pg_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE
);

CREATE TABLE `profile_health` (
    `profile_id`  VARCHAR(36) NOT NULL,
    `allergies`   TEXT,
    `conditions`  TEXT,
    `medications` TEXT,
    `updated_at`  VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `profile_health_profile_id` PRIMARY KEY (`profile_id`),
    CONSTRAINT `ph_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE
);

CREATE TABLE `profile_kitchen` (
    `profile_id`       VARCHAR(36) NOT NULL,
    `equipment`        TEXT,
    `skill_level`      VARCHAR(20),
    `max_prep_minutes` INT,
    `updated_at`       VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `profile_kitchen_profile_id` PRIMARY KEY (`profile_id`),
    CONSTRAINT `pk_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE
);

CREATE TABLE `profile_lifestyle` (
    `profile_id`          VARCHAR(36) NOT NULL,
    `schedule`            TEXT,
    `dining_out_frequency` VARCHAR(10),
    `budget`              VARCHAR(10),
    `updated_at`          VARCHAR(30) NOT NULL DEFAULT (NOW()),
    CONSTRAINT `profile_lifestyle_profile_id` PRIMARY KEY (`profile_id`),
    CONSTRAINT `pl_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE
);

CREATE TABLE `profile_preferences` (
    `profile_id`              VARCHAR(36) NOT NULL,
    `notifications_enabled`   BOOLEAN     NOT NULL DEFAULT TRUE,
    `daily_checkin_reminder`  BOOLEAN     NOT NULL DEFAULT TRUE,
    `weekly_checkin_reminder` BOOLEAN     NOT NULL DEFAULT TRUE,
    `cooking_timer_alert`     BOOLEAN     NOT NULL DEFAULT TRUE,
    `weekly_checkin_day`      VARCHAR(10) NOT NULL DEFAULT 'sunday',
    `likes`                   TEXT,
    `dislikes`                TEXT,
    CONSTRAINT `profile_preferences_profile_id` PRIMARY KEY (`profile_id`),
    CONSTRAINT `pp_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE
);

CREATE TABLE `onboarding_progress` (
    `profile_id`   VARCHAR(36) NOT NULL,
    `current_step` INT         NOT NULL DEFAULT 1,
    `completed_at` VARCHAR(30),
    CONSTRAINT `onboarding_progress_profile_id` PRIMARY KEY (`profile_id`),
    CONSTRAINT `onboarding_progress_step_range` CHECK (`current_step` >= 1 AND `current_step` <= 5),
    CONSTRAINT `op_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON DELETE CASCADE
);
