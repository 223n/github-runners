-- CI用のデータベースとユーザーを用意する。
-- GitHub Actions の services: が使えないため（理由は README を参照）、
-- ランナーと同じ compose ネットワーク上に常設の MySQL を置き、
-- ワークフローからはホスト名 mysql で参照する。
--
-- ジョブごとに分離したいものは、ここへデータベースを足して
-- ワークフロー側の DATABASE_TEST_URL を向け替える。

-- npo-tool
CREATE DATABASE IF NOT EXISTS npo_tool_test
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- sleep-diary-php
-- test ジョブは php-version × dependencies の組み合わせで動くため、
-- 同時に走っても衝突しないようデータベースを分ける。
CREATE DATABASE IF NOT EXISTS sleep_diary_test
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE IF NOT EXISTS sleep_diary_test_lowest
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE IF NOT EXISTS sleep_diary_test_highest
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE IF NOT EXISTS sleep_diary_test_coverage
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- npo-tool のワークフローが使うユーザー（app/secret）
CREATE USER IF NOT EXISTS 'app'@'%' IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON `npo\_tool\_test`.* TO 'app'@'%';
GRANT ALL PRIVILEGES ON `sleep\_diary\_test%`.* TO 'app'@'%';
FLUSH PRIVILEGES;
