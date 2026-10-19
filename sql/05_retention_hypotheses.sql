
-- =========================================================
-- Проект: Анализ Retention платформы IT Resume
-- Файл: 05_retention_hypotheses.sql
-- СУБД: PostgreSQL
-- =========================================================


-- ЗАПРОС 1. РЕГУЛЯРНОСТЬ ОБУЧЕНИЯ И RETENTION
--
-- Цель:
-- Сравнить Retention D30-D59 пользователей,
-- занимавшихся 0-1 день и 2+ дня в первую неделю.
--
-- Учебный день = 24-часовой интервал
-- с момента регистрации, содержащий учебное событие.
--
-- Результаты необходимо повторно сверить с БД.

WITH learning AS (
    SELECT user_id, created_at FROM public.coderun
    UNION ALL
    SELECT user_id, created_at FROM public.codesubmit
    UNION ALL
    SELECT user_id, created_at FROM public.teststart
    UNION ALL
    SELECT user_id, created_at FROM public.testresult
),

events AS (
    SELECT user_id, entry_at AS event_at
    FROM public.userentry

    UNION ALL

    SELECT user_id, created_at
    FROM learning
),

cohort AS (
    SELECT
        id,
        date_joined
    FROM public.users
    WHERE date_joined >= DATE '2021-11-01'
      AND date_joined < DATE '2022-03-26'
),

user_features AS (
    SELECT
        c.id,
        c.date_joined,

        COUNT(
            DISTINCT FLOOR(
                EXTRACT(
                    EPOCH FROM (l.created_at - c.date_joined)
                ) / 86400
            )
        ) AS learning_days

    FROM cohort AS c
    LEFT JOIN learning AS l
        ON l.user_id = c.id
       AND l.created_at >= c.date_joined
       AND l.created_at < c.date_joined + INTERVAL '7 days'

    GROUP BY
        c.id,
        c.date_joined
),

user_retention AS (
    SELECT
        f.id,
        f.learning_days,

        EXISTS (
            SELECT 1
            FROM events AS e
            WHERE e.user_id = f.id
              AND e.event_at >= f.date_joined
                  + INTERVAL '30 days'
              AND e.event_at < f.date_joined
                  + INTERVAL '60 days'
        ) AS retained

    FROM user_features AS f
)

SELECT
    CASE
        WHEN learning_days >= 2 THEN '2+ дня'
        ELSE '0-1 день'
    END AS activity_group,

    COUNT(*) AS users_count,

    COUNT(*) FILTER (
        WHERE retained
    ) AS retained_users,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE retained)
        / NULLIF(COUNT(*), 0),
        2
    ) AS retention_pct

FROM user_retention
GROUP BY 1
ORDER BY 1;


-- ЗАПРОС 2. ПРОВЕРКА ГИПОТЕЗЫ ПО КОГОРТАМ
--
-- Цель:
-- Убедиться, что связь ранней регулярности
-- и долгосрочного Retention наблюдается
-- в разных месяцах регистрации.
--
-- Когорта марта ограничена датой 25.03.2022.

WITH learning AS (
    SELECT user_id, created_at FROM public.coderun
    UNION ALL
    SELECT user_id, created_at FROM public.codesubmit
    UNION ALL
    SELECT user_id, created_at FROM public.teststart
    UNION ALL
    SELECT user_id, created_at FROM public.testresult
),

events AS (
    SELECT user_id, entry_at AS event_at
    FROM public.userentry

    UNION ALL

    SELECT user_id, created_at
    FROM learning
),

cohort AS (
    SELECT
        id,
        date_joined,
        DATE_TRUNC('month', date_joined)::date
            AS cohort_month
    FROM public.users
    WHERE date_joined >= DATE '2021-11-01'
      AND date_joined < DATE '2022-03-26'
),

user_features AS (
    SELECT
        c.id,
        c.date_joined,
        c.cohort_month,

        COUNT(
            DISTINCT FLOOR(
                EXTRACT(
                    EPOCH FROM (l.created_at - c.date_joined)
                ) / 86400
            )
        ) AS learning_days

    FROM cohort AS c
    LEFT JOIN learning AS l
        ON l.user_id = c.id
       AND l.created_at >= c.date_joined
       AND l.created_at < c.date_joined + INTERVAL '7 days'

    GROUP BY
        c.id,
        c.date_joined,
        c.cohort_month
),

user_retention AS (
    SELECT
        f.id,
        f.cohort_month,
        f.learning_days,

        EXISTS (
            SELECT 1
            FROM events AS e
            WHERE e.user_id = f.id
              AND e.event_at >= f.date_joined
                  + INTERVAL '30 days'
              AND e.event_at < f.date_joined
                  + INTERVAL '60 days'
        ) AS retained

    FROM user_features AS f
)

SELECT
    cohort_month,

    CASE
        WHEN learning_days >= 2 THEN '2+ дня'
        ELSE '0-1 день'
    END AS activity_group,

    COUNT(*) AS users_count,

    COUNT(*) FILTER (
        WHERE retained
    ) AS retained_users,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE retained)
        / NULLIF(COUNT(*), 0),
        2
    ) AS retention_pct

FROM user_retention
GROUP BY
    cohort_month,
    activity_group
ORDER BY
    cohort_month,
    activity_group;
