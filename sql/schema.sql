CREATE TABLE spell (
  spell_id   INTEGER PRIMARY KEY,
  person_id  INTEGER NOT NULL,
  state_from INTEGER NOT NULL,
  state_to   INTEGER,
  start_time REAL NOT NULL,
  end_time   REAL NOT NULL
)