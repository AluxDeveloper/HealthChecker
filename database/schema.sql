-- Schema bazei de date „sarcini” (PostgreSQL).
--
-- Aplicația rulează acest fișier la fiecare conectare, deci toate
-- comenzile trebuie să poată fi repetate fără efecte nedorite.
--
-- Rulare manuală:  psql -U sarcini_app -d sarcini -f database/schema.sql

-- Toate programările, cu absolut toate detaliile lor.
CREATE TABLE IF NOT EXISTS tasks (
  id           bigint      PRIMARY KEY,
  title        text        NOT NULL,
  notes        text        NOT NULL DEFAULT '',
  category     text        NOT NULL DEFAULT 'general'
               CHECK (category IN ('medication', 'hydration', 'activity',
                                   'sleep', 'appointment', 'general')),
  due_at       timestamptz NOT NULL,              -- data și ora programării
  remind       boolean     NOT NULL DEFAULT true, -- notificare activă
  done         boolean     NOT NULL DEFAULT false,
  completed_at timestamptz,                       -- când a fost bifată
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz                        -- NULL = nu e ștearsă
);

COMMENT ON TABLE tasks IS
  'Programările din aplicația Sarcini. Rândurile dispar automat la 3 zile '
  'după ștergere sau după ora programată (vezi purge_expired_tasks).';

-- Momentul la care o programare dispare definitiv: la 3 zile după ștergere
-- sau după ora programată, oricare vine prima. (72 de ore exact, ca în
-- aplicație: Task.retention.)
CREATE OR REPLACE FUNCTION task_expires_at(
  due_at timestamptz,
  deleted_at timestamptz
) RETURNS timestamptz
LANGUAGE sql IMMUTABLE AS $$
  SELECT LEAST(due_at, deleted_at) + interval '72 hours'
$$;

-- Șterge definitiv programările expirate; întoarce câte au fost șterse.
CREATE OR REPLACE FUNCTION purge_expired_tasks() RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
  removed integer;
BEGIN
  DELETE FROM tasks WHERE task_expires_at(due_at, deleted_at) <= now();
  GET DIAGNOSTICS removed = ROW_COUNT;
  RETURN removed;
END
$$;

-- Istoricul: programările șterse sau a căror oră a trecut.
CREATE OR REPLACE VIEW task_history AS
SELECT
  t.*,
  CASE WHEN t.deleted_at IS NOT NULL THEN 'stearsa' ELSE 'expirata' END
    AS motiv,
  task_expires_at(t.due_at, t.deleted_at) AS dispare_la
FROM tasks t
WHERE t.deleted_at IS NOT NULL OR t.due_at < now()
ORDER BY COALESCE(t.deleted_at, t.due_at) DESC;
