
-- =========================================================
-- Проект: Анализ Retention платформы IT Resume
-- Файл: 01_data_quality.sql
-- СУБД: PostgreSQL
-- =========================================================

-- Цель:
-- Проверить соответствие событий посещений
-- пользователям, зарегистрированным на платформе.

SELECT
    COUNT(*) AS events_total,

    COUNT(*) FILTER (
        WHERE u.id IS NULL
    ) AS unmatched_events,

    COUNT(DISTINCT e.user_id) FILTER (
        WHERE u.id IS NULL
    ) AS unmatched_ids

FROM public.userentry AS e

LEFT JOIN public.users AS u
    ON e.user_id = u.id;
