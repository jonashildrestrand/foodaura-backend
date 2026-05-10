-- V004: Add diet_type to nutritional_profiles
-- Stores the user's dietary preference for use in recipe filtering and AI meal planning.

SET NAMES utf8mb4;

ALTER TABLE nutritional_profiles
  ADD COLUMN diet_type ENUM('omnivore','vegetarian','vegan','pescatarian')
    NOT NULL DEFAULT 'omnivore'
  AFTER goal;
