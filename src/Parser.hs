module Parser where

import           Text.Parsec
import           Text.Parsec.String

import           Data.List          (isSuffixOf)

import           Constants
import           Types

parseFile :: FilePath -> Sparker [Card]
parseFile file = do
    str <- liftIO $ readFile file
    case parse sparkFile file str of
        Left pe -> throwError $ ParseError pe
        Right cs -> return cs


parseCardReference :: String -> Either ParseError CardReference
parseCardReference = parse cardReference "Raw String"


---[ Parsing ]---

sparkFile :: Parser [Card]
sparkFile = do
    clean <- eatComments
    setInput clean
    resetPosition
    sepEndBy1 card whitespace

resetPosition :: Parser ()
resetPosition = do
    pos <- getPosition
    setPosition $ setSourceColumn (setSourceLine pos 1) 1


getFile :: Parser FilePath
getFile = do
    pos <- getPosition
    let file = sourceName pos
    return file

card :: Parser Card
card = do
    whitespace
    string keywordCard
    whitespace
    name <- cardName
    whitespace
    Block ds <- block
    whitespace
    fp <- getFile
    return $ Card name fp ds

cardName :: Parser CardName
cardName = try quotedIdentifier <|> try plainIdentifier <?> "card name"

declarations :: Parser [Declaration]
declarations = (inLineSpace declaration) `sepEndBy` delim

declaration :: Parser Declaration
declaration = choice $ map try
    [
      block
    , alternatives
    , sparkOff
    , intoDir
    , outOfDir
    , deploymentKindOverride
    , deployment
    ]

block :: Parser Declaration
block = do
    ds <- inBraces $ inWhiteSpace declarations
    return $ Block ds
    <?> "block"

sparkOff :: Parser Declaration
sparkOff = do
    string keywordSpark
    linespace
    ref <- cardReference
    return $ SparkOff ref
    <?> "sparkoff"

cardReference :: Parser CardReference
cardReference = try cardNameReference <|> try cardFileReference <|> try cardRepoReference
    <?> "card reference"

cardNameReference :: Parser CardReference
cardNameReference = do
    string keywordCard
    linespace
    name <- cardName
    return $ CardName name
    <?> "card name reference"

cardFileReference :: Parser CardReference
cardFileReference = do
    string keywordFile
    linespace
    fp <- filepath
    linespace
    mn <- optionMaybe $ try cardName
    return $ CardFile fp mn
    <?> "card file reference"

cardRepoReference :: Parser CardReference
cardRepoReference = do
    string keywordGit
    linespace
    repo <- gitRepo
    mb <- optionMaybe $ try $ do
        string branchDelimiter
        branch
    mfpcn <- optionMaybe $ try $ do
        linespace
        fp <- filepath
        linespace
        mcn <- optionMaybe $ try cardName
        return (fp, mcn)
    return $ CardRepo repo mb mfpcn
    <?> "card git reference"
  where
    branch :: Parser Branch
    branch = cardName -- Fix this is this is not quite enough.

intoDir :: Parser Declaration
intoDir = do
    string keywordInto
    linespace
    dir <- directory
    return $ IntoDir dir
    <?> "into directory declaration"

outOfDir :: Parser Declaration
outOfDir = do
    string keywordOutof
    linespace
    dir <- directory
    return $ OutofDir dir
    <?> "outof directory declaration"

deploymentKindOverride :: Parser Declaration
deploymentKindOverride = do
    string keywordKindOverride
    linespace
    kind <- try copy <|> link
    return $ DeployKindOverride kind
    <?> "deployment kind override"
  where
    copy = string keywordCopy >> return CopyDeployment
    link = string keywordLink >> return LinkDeployment

deployment :: Parser Declaration
deployment = do
    source <- filepath
    linespace
    kind <- deploymentKind
    linespace
    dest <- filepath
    return $ Deploy source dest kind
    <?> "deployment"

deploymentKind :: Parser (Maybe DeploymentKind)
deploymentKind = try link <|> try copy <|> def
    <?> "deployment kind"
    where
        link = string linkKindSymbol >> return (Just LinkDeployment)
        copy = string copyKindSymbol >> return (Just CopyDeployment)
        def  = string unspecifiedKindSymbol >> return Nothing

alternatives :: Parser Declaration
alternatives = do
    string keywordAlternatives
    linespace
    ds <- directory `sepBy1` linespace
    return $ Alternatives ds

-- [ FilePaths ]--

filepath :: Parser FilePath
filepath = try quotedIdentifier <|> plainIdentifier

directory :: Parser Directory
directory = do
    d <- filepath
    return $ if "/" `isSuffixOf` d
    then init d
    else d
    <?> "directory"


--[ Comments ]--

comment :: Parser String
comment = lineComment <|> blockComment

lineComment :: Parser String
lineComment = do
    skip $ string lineCommentStr
    anyChar `manyTill` try (lookAhead eol)

blockComment :: Parser String
blockComment = do
    skip $ string start
    anyChar `manyTill` try (lookAhead $ string stop)
  where (start, stop) = blockCommentStrs


skip :: Parser a -> Parser ()
skip f = f >> return ()

notComment :: Parser String
notComment = manyTill anyChar (lookAhead ((skip comment) <|> eof))

eatComments :: Parser String
eatComments = do
  optional comment
  xs <- notComment `sepBy` comment
  optional comment
  let withoutComments = concat xs
  return withoutComments


-- Identifiers

plainIdentifier :: Parser String
plainIdentifier = many1 $ noneOf $ quotesChar : lineDelimiter ++ whitespaceChars ++ bracesChars

quotedIdentifier :: Parser String
quotedIdentifier = inQuotes $ many $ noneOf $ quotesChar:endOfLineChars


--[ Delimiters ]--

inBraces :: Parser a -> Parser a
inBraces = between (char '{') (char '}')

inQuotes :: Parser a -> Parser a
inQuotes = between (char quotesChar) (char quotesChar)

delim :: Parser String
delim = try (string lineDelimiter) <|> go
  where
    go = do
        e <- eol
        ws <- whitespace
        return $ e ++ ws


--[ Whitespace ]--

inLineSpace :: Parser a -> Parser a
inLineSpace = between linespace linespace

inWhiteSpace :: Parser a -> Parser a
inWhiteSpace = between whitespace whitespace

linespace :: Parser String
linespace = many $ oneOf linespaceChars

whitespace :: Parser String
whitespace = many $ oneOf whitespaceChars

eol :: Parser String
eol =   try (string "\n\r")
    <|> try (string "\r\n")
    <|> try (string "\n")
    <|> string "\r"
    <?> "end of line"


--[ Git ]--

gitRepo :: Parser GitRepo
gitRepo = do
    prot <- gitProtocol
    case prot of
        HTTPS -> do
            host <- manyTill anyToken (string "/")
            path <- many anyToken
            return $ GitRepo {
                    repo_protocol = HTTPS, repo_host = host, repo_path = path
                }
        Git   -> do
            host <- manyTill anyToken (string ":")
            path <- manyTill anyToken (string ".git")
            return $ GitRepo {
                    repo_protocol = Git, repo_host = host, repo_path = path
                }

gitProtocol :: Parser GitProtocol
gitProtocol = https <|> git
  where
    https = string "https://" >> return HTTPS
    git   = string "git@"     >> return Git
