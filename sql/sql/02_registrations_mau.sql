
-- =========================================================
-- Проект: Анализ Retention платформы IT Resume
-- Файл: 02_registrations_mau.sql
-- СУБД: PostgreSQL
-- =========================================================


-- ЗАПРОС 1. ДИНАМИКА РЕГИСТРАЦИЙ
--
-- Цель:
-- Определить количество новых пользователей
-- по месяцам.

SELECT
    DATE_TRUNC('month', date_joined)::date AS month,
    COUNT(*) AS registrations
FROM public.users
GROUP BY 1
ORDER BY 1;


-- ЗАПРОС 2. МЕСЯЧНАЯ АКТИВНОСТЬ (MAU)
--
-- Цель:
-- Рассчитать MAU и разделить активных пользователей
-- на новых и вернувшихся.
--
-- MAU: количество уникальных пользователей,
-- совершивших хотя бы одно событие посещения
-- в календарном месяце.
--
-- new_active: зарегистрировались в этом месяце.
-- returning_active: зарегистрировались ранее.

WITH monthly AS (
    SELECT DISTINCT
        u.id,
        DATE_TRUNC('month', e.entry_at)::date AS month,
        DATE_TRUNC('month', u.date_joined)::date
            AS registration_month
    FROM public.userentry AS e
    JOIN public.users AS u
        ON u.id = e.user_id
)

SELECT
    month,
    COUNT(*) AS mau,

    COUNT(*) FILTER (
        WHERE registration_month = month
    ) AS new_active,

    COUNT(*) FILTER (
        WHERE registration_month < month
    ) AS returning_active

FROM monthly
GROUP BY month
ORDER BY month;
