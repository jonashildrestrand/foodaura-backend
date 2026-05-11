-- R__99: Grant EXECUTE on all stored procedures to application database users.
-- Repeatable migration — runs last (alphabetically highest R__ file) so all
-- procedures exist before grants are applied. Re-runs whenever this file changes,
-- which is needed when new procedures are added.

SET NAMES utf8mb4;

-- ─── foodaura_backend — execute all stored procedures ────────────────────────

GRANT EXECUTE ON PROCEDURE foodaura.sp_goals_list                    TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_diet_types_list               TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_auth_get_user                 TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_auth_create_user              TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_auth_get_user_by_email        TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_auth_create_session           TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_auth_get_session              TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_auth_delete_session           TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_household_find_by_user        TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_household_create              TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_household_get                 TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_household_invite              TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_household_accept_invitation   TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_household_remove_member       TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_household_leave               TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_household_get_member_preferences TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_profile_upsert                TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_profile_get                   TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_targets_get                   TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_recipe_find                   TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_recipe_get                    TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_recipe_scale                  TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_tag_category_list             TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_tag_list                      TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_recipe_tags_set               TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_preference_set_recipe         TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_preference_add_ingredient_dislike    TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_preference_remove_ingredient_dislike TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_mealplan_get_or_create        TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_mealplan_get                  TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_mealplan_assign_recipe        TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_mealplan_clear_slot           TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_mealplan_get_history          TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_mealplan_copy                 TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_mealplan_notify_ready         TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_mealplan_bulk_assign          TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_mealplan_get_nutrition_summary TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_shoppinglist_derive           TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_shoppinglist_get              TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_shoppinglist_toggle_item      TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_notification_unread_count     TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_notification_create           TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_notification_get_all          TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_notification_mark_read        TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_notification_mark_all_read    TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_schedule_template_upsert      TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_schedule_template_get         TO 'foodaura_backend'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_schedule_template_apply       TO 'foodaura_backend'@'%';

-- ─── foodaura_ai — read-only and bulk-assign procedures ──────────────────────

GRANT EXECUTE ON PROCEDURE foodaura.sp_ai_get_household_profiles     TO 'foodaura_ai'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_recipe_find                   TO 'foodaura_ai'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_recipe_get                    TO 'foodaura_ai'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_mealplan_get                  TO 'foodaura_ai'@'%';
GRANT EXECUTE ON PROCEDURE foodaura.sp_mealplan_bulk_assign          TO 'foodaura_ai'@'%';

FLUSH PRIVILEGES;
