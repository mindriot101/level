defmodule Level.Repo.Migrations.CreateDueNudgesView do
  use Ecto.Migration

  def up do
    execute """
    CREATE VIEW due_nudges AS
      SELECT n2.*
      FROM (
        SELECT n.*, u.time_zone,
          ((date_part('hour', timezone(u.time_zone, now()))::integer * 60) + date_part('minute', timezone(u.time_zone, now()))::integer) AS current_minute
        FROM nudges n
        INNER JOIN space_users su ON n.space_user_id = su.id
        INNER JOIN users u ON su.user_id = u.id
      ) n2
      LEFT OUTER JOIN digests d
        ON d.key = concat('nudge:', n2.id, ':', to_char(NOW() AT TIME ZONE n2.time_zone, 'yyyy-mm-dd'))
      WHERE n2.current_minute >= n2.minute
        AND n2.current_minute < n2.minute + 30
        AND d.id IS NULL
    """
  end

  def down do
    execute "DROP VIEW due_nudges"
  end
end
