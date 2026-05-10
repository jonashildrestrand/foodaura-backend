-- V005: Add recipe tag system (tag_categories, tags, recipe_tags)
-- Supports discover-page filter chips and recipe card tag display.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS tag_categories (
  id   CHAR(36)     NOT NULL DEFAULT (UUID()),
  name VARCHAR(100) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tag_categories_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS tags (
  id          CHAR(36)     NOT NULL DEFAULT (UUID()),
  category_id CHAR(36)     NOT NULL,
  name        VARCHAR(100) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tags_category_name (category_id, name),
  CONSTRAINT fk_tags_category FOREIGN KEY (category_id) REFERENCES tag_categories (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS recipe_tags (
  recipe_id CHAR(36) NOT NULL,
  tag_id    CHAR(36) NOT NULL,
  PRIMARY KEY (recipe_id, tag_id),
  CONSTRAINT fk_rt_recipe FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE,
  CONSTRAINT fk_rt_tag    FOREIGN KEY (tag_id)    REFERENCES tags    (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

-- Seed default tag categories and tags used across the app
INSERT IGNORE INTO tag_categories (id, name) VALUES
  ('00000000-seed-0000-tag-category000001', 'diet'),
  ('00000000-seed-0000-tag-category000002', 'meal'),
  ('00000000-seed-0000-tag-category000003', 'cuisine');

INSERT IGNORE INTO tags (id, category_id, name) VALUES
  -- diet tags
  ('00000000-seed-0000-0000-tag000000001', '00000000-seed-0000-tag-category000001', 'vegan'),
  ('00000000-seed-0000-0000-tag000000002', '00000000-seed-0000-tag-category000001', 'vegetarian'),
  ('00000000-seed-0000-0000-tag000000003', '00000000-seed-0000-tag-category000001', 'pescatarian'),
  ('00000000-seed-0000-0000-tag000000004', '00000000-seed-0000-tag-category000001', 'gluten-free'),
  ('00000000-seed-0000-0000-tag000000005', '00000000-seed-0000-tag-category000001', 'dairy-free'),
  ('00000000-seed-0000-0000-tag000000006', '00000000-seed-0000-tag-category000001', 'high-protein'),
  -- meal tags
  ('00000000-seed-0000-0000-tag000000007', '00000000-seed-0000-tag-category000002', 'quick'),
  ('00000000-seed-0000-0000-tag000000008', '00000000-seed-0000-tag-category000002', 'meal-prep'),
  ('00000000-seed-0000-0000-tag000000009', '00000000-seed-0000-tag-category000002', 'budget'),
  -- cuisine tags
  ('00000000-seed-0000-0000-tag000000010', '00000000-seed-0000-tag-category000003', 'italian'),
  ('00000000-seed-0000-0000-tag000000011', '00000000-seed-0000-tag-category000003', 'asian'),
  ('00000000-seed-0000-0000-tag000000012', '00000000-seed-0000-tag-category000003', 'mediterranean');
