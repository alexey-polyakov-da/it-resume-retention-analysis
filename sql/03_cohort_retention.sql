
-- =========================================================
-- Проект: Анализ Retention платформы IT Resume
-- Файл: 03_cohort_retention.sql
-- СУБД: PostgreSQL
-- =========================================================


-- ЗАПРОС 1. КОГОРТНЫЙ M1 RETENTION
--
-- Цель:
-- Определить долю пользователей, посетивших платформу
-- в календарном месяце после месяца регистрации.
--
-- Пример:
-- Пользователь зарегистрировался 15 января.
-- M1 = наличие посещения в феврале.
--
-- Метрика основана на таблице userentry.

WITH cohorts AS (
    SELECT
        id,
        DATE_TRUNC('month', date_joined)::date AS cohort
    FROM public.users
),

next_month AS (
    SELECT DISTINCT
        c.id,
        c.cohort
    FROM cohorts AS c
    JOIN public.userentry AS e
        ON e.user_id = c.id
       AND DATE_TRUNC('month', e.entry_at)
           = c.cohort + INTERVAL '1 month'
)

SELECT
    c.cohort,
    COUNT(*) AS cohort_size,
    COUNT(n.id) AS retained_users,

    ROUND(
        100.0 * COUNT(n.id) / NULLIF(COUNT(*), 0),
        2
    ) AS retention_pct

FROM cohorts AS c
LEFT JOIN next_month AS n
    ON n.id = c.id
GROUP BY c.cohort
ORDER BY c.cohort;


-- ЗАПРОС 2. RETENTION D30-D59
--
-- Цель:
-- Рассчитать долгосрочное удержание пользователей.
--
-- Удержанным считается пользователь, совершивший
-- хотя бы одно событие посещения или обучения
-- с 30-го дня (включительно)
-- до 60-го дня (не включительно) после регистрации.
--
-- Период когорт:
-- 01.11.2021 - 25.03.2022 включительно.
--
-- Используем:
-- userentry, coderun, codesubmit, teststart, testresult.

WITH events AS (
    SELECT
        user_id,
        entry_at AS event_at
    FROM public.userentry

    UNION ALL

    SELECT user_id, created_at
    FROM public.coderun

    UNION ALL

    SELECT user_id, created_at
    FROM public.codesubmit

    UNION ALL

    SELECT user_id, created_at
    FROM public.teststart

    UNION ALL

    SELECT user_id, created_at
    FROM public.testresult
),

cohort AS (
    SELECT
        id,
        date_joined
    FROM public.users
    WHERE date_joined >= DATE '2021-11-01'
      AND date_joined < DATE '2022-03-26'
)

SELECT
    COUNT(*) AS users_count,

    COUNT(*) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM events AS e
            WHERE e.user_id = c.id
              AND e.event_at >= c.date_joined
                  + INTERVAL '30 days'
              AND e.event_at < c.date_joined
                  + INTERVAL '60 days'
        )
    ) AS retained_users,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE EXISTS (
                SELECT 1
                FROM events AS e
                WHERE e.user_id = c.id
                  AND e.event_at >= c.date_joined
                      + INTERVAL '30 days'
                  AND e.event_at < c.date_joined
                      + INTERVAL '60 days'
            )
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS retention_pct

FROM cohort AS c;
