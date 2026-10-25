SELECT state_from, state_to, COUNT(*) AS n
FROM spell
WHERE state_to IS NOT NULL
GROUP BY state_from, state_to
ORDER BY state_from, state_to