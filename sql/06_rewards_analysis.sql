
-- =========================================================
-- Проект: Анализ Retention платформы IT Resume
-- Файл: 06_rewards_analysis.sql
-- СУБД: PostgreSQL
-- =========================================================


-- ЗАПРОС 1. АНАЛИЗ СИСТЕМЫ ПООЩРЕНИЙ
--
-- Цель:
-- Определить количество транзакций по каждому
-- типу бонусов и число уникальных пользователей.
--
-- Используем:
-- transaction и transactiontype.
--
-- Важно:
-- transaction.value не следует интерпретировать
-- как выручку в рублях без подтверждения семантики.

SELECT
    tt.type AS transaction_type,
    tt.description,

    COUNT(t.id) AS transactions_count,

    COUNT(DISTINCT t.user_id) AS unique_users,

    SUM(t.value) AS total_value,

    MIN(t.created_at)::date AS first_transaction,

    MAX(t.created_at)::date AS last_transaction

FROM public.transactiontype AS tt

LEFT JOIN public.transaction AS t
    ON t.type_id = tt.type

GROUP BY
    tt.type,
    tt.description

ORDER BY
    transactions_count DESC,
    tt.type;


-- ЗАПРОС 2. ОХВАТ НЕДЕЛЬНОГО МАРАФОНА
--
-- Цель:
-- Определить, сколько пользователей получили
-- начисление за недельный марафон
-- в первые семь суток после регистрации.
--
-- Код марафона в transactiontype: type = 5.
--
-- Исследуемая когорта:
-- 01.11.2021 - 25.03.2022 включительно.

SELECT
    COUNT(DISTINCT u.id) AS total_users,

    COUNT(DISTINCT u.id) FILTER (
        WHERE t.id IS NOT NULL
    ) AS marathon_users,

    COUNT(t.id) AS marathon_transactions,

    ROUND(
        100.0 * COUNT(DISTINCT u.id) FILTER (
            WHERE t.id IS NOT NULL
        ) / NULLIF(COUNT(DISTINCT u.id), 0),
        2
    ) AS marathon_share_pct

FROM public.users AS u

LEFT JOIN public.transaction AS t
    ON t.user_id = u.id
   AND t.type_id = 5
   AND t.created_at >= u.date_joined
   AND t.created_at < u.date_joined + INTERVAL '7 days'

WHERE u.date_joined >= DATE '2021-11-01'
  AND u.date_joined < DATE '2022-03-26';
