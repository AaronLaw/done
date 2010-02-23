-- what done.hs
-- who  nate smith
-- why  an elegant and basic approach to todo listing
-- when feb 2010

import System.IO
import System.Environment ( getArgs )
import Database.HDBC
import Database.HDBC.Sqlite3

-- adlbh

---- add task
add :: Connection -> [String] -> IO ()
add dbh argv = do
    case argv of
        (x:[])     -> insertTask dbh (head argv)
        (x:y:z:[]) -> insertTaskDueDate dbh (head argv) (last argv)
        []         -> help
        _          -> help

insertTask :: Connection -> String -> IO ()
insertTask dbh desc = do
    run dbh "INSERT INTO tasks VALUES (null, ?, null, (SELECT CURRENT_TIMESTAMP), 'f')" [toSql desc]
    commit dbh
    putStrLn $ "\tadded " ++ desc

insertTaskDueDate :: Connection -> String -> String -> IO ()
insertTaskDueDate dbh desc due = do
    run dbh "INSERT INTO tasks VALUES (null, ?, ?, (SELECT CURRENT_TIMESTAMP), 'f')" [toSql desc, (toSql (parseDate due))]
    commit dbh
    putStrLn $ "\tadded " ++ desc ++ " (due: " ++ (parseDate due) ++ ")"

-- stubbed for now:
parseDate :: String -> String
parseDate due = "2011-02-21 19:55:17"

---- finish a task
done :: Connection -> [String] -> IO ()
done dbh argv =
    case argv of
        []     -> finishTask dbh
        (x:[]) -> finishTaskFilter dbh x
        _      -> help

finishTask :: Connection -> IO ()
finishTask dbh = do
    r <- quickQuery dbh "SELECT desc FROM tasks WHERE done = 'f' ORDER BY due_ts, created_ts" []
    putStrLn "finished with..."
    donePrompt dbh (map fromSql (map head r))

finishTaskFilter :: Connection -> String -> IO ()
finishTaskFilter dbh desc = do
    r <- quickQuery dbh "SELECT desc FROM tasks WHERE desc LIKE ? AND done = 'f' ORDER BY due_ts, created_ts" [toSql $ "%"++desc++"%"]
    putStrLn "finished with..."
    donePrompt dbh (map fromSql (map head r))

donePrompt :: Connection -> [String] -> IO ()
donePrompt dbh (x:[]) = do prompt dbh x
donePrompt dbh (x:xs) = do
    prompt dbh x
    donePrompt dbh xs

prompt :: Connection -> String -> IO ()
prompt dbh desc = do
    putStr $ "\t" ++ desc ++ "? [y/N] "
    answer <- getLine
    case answer of
        "y" -> finishOff dbh desc
        "Y" -> finishOff dbh desc
        _   -> putStr ""

finishOff :: Connection -> String -> IO ()
finishOff dbh desc = do
    run dbh "UPDATE tasks SET done='t' WHERE desc=?" [toSql desc]
    commit dbh
    putStrLn $ "\t\tX " ++ desc

---- list out tasks
list :: Connection -> [String] -> IO ()
list dbh [] = do
    r <- quickQuery dbh "SELECT desc FROM tasks WHERE done = 'f' ORDER BY due_ts, created_ts" []
    listOut (map fromSql (map head r))

list dbh (x:[]) = do
    r <- quickQuery dbh "SELECT desc FROM tasks WHERE desc LIKE ? AND done = 'f' ORDER BY due_ts, created_ts" [toSql $ "%"++x++"%"]
    listOut (map fromSql (map head r))

listOut :: [String] -> IO ()
listOut (x:[]) = do putStrLn x
listOut (x:xs) = do
    putStrLn x
    listOut xs

---- go to sqlite3 backend
backend :: IO ()
backend = putStrLn "launch sqlite3"

help :: IO ()
help = putStrLn "available commands: aldh"

connectDB :: IO Connection
connectDB = do
    dbh <- connectSqlite3 "done.db"
    return dbh

runCommand :: Connection -> String -> [String] -> IO ()
runCommand dbh cmd argv =
    case cmd of
        "a" -> add dbh argv
        "d" -> done dbh argv
        "l" -> list dbh argv
        "b" -> backend
        "h" -> help
        _   -> putStrLn $ "I don't understand: " ++ cmd

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    dbh <- connectDB 
    argv <- getArgs
    case argv of
        [] -> help
        _  -> runCommand dbh (head argv) (tail argv) 
