-- Verify Instruments has user_note column
SELECT name FROM pragma_table_info('Instruments') WHERE name='user_note';

-- Ensure existing rows have NULL user_note
SELECT COUNT(*) AS user_note_non_null FROM Instruments WHERE user_note IS NOT NULL;
