BEGIN;

	CREATE OR REPLACE FUNCTION Levenshtein(str1 VARCHAR, str2 VARCHAR) RETURNS INT AS $$
		DECLARE
			len1 int := LENGTH(str1);
			len2 int := LENGTH(str2);
			d int[][] := array_fill(0, ARRAY[len1 + 1, len2 + 1]);
			i int;
			j int;
		BEGIN
			IF len1 = 0 THEN
				RETURN len2;
			ELSIF len2 = 0 THEN
				RETURN len1;
			END IF;

			FOR i IN 1..len1 LOOP
				d[i+1][1] := i;
			END LOOP;

			FOR j IN 1..len2 LOOP
				d[1][j+1] := j;
			END LOOP;

			FOR j IN 2..len2+1 LOOP
				FOR i IN 2..len1+1 LOOP
					IF SUBSTRING(str1, i-1, 1) = SUBSTRING(str2, j-1, 1) THEN
						d[i][j] := d[i-1][j-1];
					ELSE
						d[i][j] := LEAST(d[i-1][j], d[i][j-1], d[i-1][j-1]) + 1;
					END IF;
				END LOOP;
			END LOOP;

			RETURN d[len1+1][len2+1];

		END;
	$$ LANGUAGE plpgsql;	
	
	CREATE OR REPLACE FUNCTION Shortened_Middle_Name(_name VARCHAR) RETURNS VARCHAR AS $$
		DECLARE 
            _first_name VARCHAR;
		    _middle_name VARCHAR;
		    _surname VARCHAR;
		BEGIN
            SELECT INTO _first_name, _middle_name, _surname
                SPLIT_PART(_name, ' ', 1),
                SPLIT_PART(_name, ' ', 2),
                SPLIT_PART(_name, ' ', 3);
            RETURN _first_name || ' ' || SUBSTRING(_middle_name, 1, 1) || '. ' || _surname;
			
		END;
	$$ LANGUAGE plpgsql;
	
ROLLBACK;