-- Schema bazei de date „sarcini” pe Supabase.
--
-- Se rulează în Supabase → SQL Editor. Poate fi rulată de mai multe ori.
-- Aplicația nu se mai conectează direct la bază: folosește API-ul Supabase
-- (HTTPS) cu un cont anonim creat automat la prima pornire.

-- Toate programările, cu absolut toate detaliile lor. Fiecare rând aparține
-- unui utilizator; id-ul e generat de aplicație și e unic per utilizator.
CREATE TABLE IF NOT EXISTS tasks (
  user_id      uuid        NOT NULL DEFAULT auth.uid()
               REFERENCES auth.users (id) ON DELETE CASCADE,
  id           bigint      NOT NULL,
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
  deleted_at   timestamptz,                       -- NULL = nu e ștearsă
  PRIMARY KEY (user_id, id)
);

COMMENT ON TABLE tasks IS
  'Programările din aplicația Sarcini. Rândurile dispar automat la 3 zile '
  'după ștergere sau după ora programată (vezi purge_expired_tasks).';

-- Momentul la care o programare dispare definitiv: la 3 zile după ștergere
-- sau după ora programată, oricare vine prima (ca în aplicație: Task.retention).
CREATE OR REPLACE FUNCTION task_expires_at(
  due_at timestamptz,
  deleted_at timestamptz
) RETURNS timestamptz
LANGUAGE sql IMMUTABLE AS $$
  SELECT LEAST(due_at, deleted_at) + interval '72 hours'
$$;

CREATE INDEX IF NOT EXISTS tasks_expires_at_idx
  ON tasks (task_expires_at(due_at, deleted_at));

-- Șterge definitiv programările expirate; întoarce câte au fost șterse.
CREATE OR REPLACE FUNCTION purge_expired_tasks() RETURNS integer
LANGUAGE plpgsql SET search_path = public AS $$
DECLARE
  removed integer;
BEGIN
  DELETE FROM tasks WHERE task_expires_at(due_at, deleted_at) <= now();
  GET DIAGNOSTICS removed = ROW_COUNT;
  RETURN removed;
END
$$;

-- Istoricul: programările șterse sau a căror oră a trecut.
CREATE OR REPLACE VIEW task_history WITH (security_invoker = true) AS
SELECT
  t.*,
  CASE WHEN t.deleted_at IS NOT NULL THEN 'stearsa' ELSE 'expirata' END
    AS motiv,
  task_expires_at(t.due_at, t.deleted_at) AS dispare_la
FROM tasks t
WHERE t.deleted_at IS NOT NULL OR t.due_at < now()
ORDER BY COALESCE(t.deleted_at, t.due_at) DESC;

-- Salvează mai multe sarcini deodată. Un rând existent e înlocuit doar dacă
-- versiunea trimisă e mai nouă (updated_at), ca la sincronizarea offline.
CREATE OR REPLACE FUNCTION upsert_tasks(items jsonb) RETURNS void
LANGUAGE sql SECURITY INVOKER SET search_path = public AS $$
  INSERT INTO tasks (user_id, id, title, notes, category, due_at, remind,
                     done, completed_at, created_at, updated_at, deleted_at)
  SELECT auth.uid(), r.id, r.title, r.notes, r.category, r.due_at, r.remind,
         r.done, r.completed_at, r.created_at, r.updated_at, r.deleted_at
  FROM jsonb_to_recordset(items) AS r(
    id bigint, title text, notes text, category text, due_at timestamptz,
    remind boolean, done boolean, completed_at timestamptz,
    created_at timestamptz, updated_at timestamptz, deleted_at timestamptz
  )
  ON CONFLICT (user_id, id) DO UPDATE SET
    title        = EXCLUDED.title,
    notes        = EXCLUDED.notes,
    category     = EXCLUDED.category,
    due_at       = EXCLUDED.due_at,
    remind       = EXCLUDED.remind,
    done         = EXCLUDED.done,
    completed_at = EXCLUDED.completed_at,
    updated_at   = EXCLUDED.updated_at,
    deleted_at   = EXCLUDED.deleted_at
  WHERE tasks.updated_at < EXCLUDED.updated_at
$$;

-- Securitate: fiecare utilizator autentificat (și cei anonimi) vede și
-- modifică doar rândurile lui. Fără cont (cheia publică singură) nu vezi nimic.
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fiecare isi vede sarcinile" ON tasks;
CREATE POLICY "fiecare isi vede sarcinile" ON tasks
  FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

REVOKE ALL ON tasks, task_history FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON tasks TO authenticated;
GRANT SELECT ON task_history TO authenticated;

REVOKE ALL ON FUNCTION purge_expired_tasks() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION upsert_tasks(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION upsert_tasks(jsonb) TO authenticated;

-- Ștergerea automată la 3 zile, o dată pe oră, chiar dacă aplicația e închisă.
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('sarcini-purge', '5 * * * *', 'SELECT purge_expired_tasks()');
