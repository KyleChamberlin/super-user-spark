module Parser.TestUtils where

import           Test.Hspec
import           Test.QuickCheck

import           Data.Either        (isLeft, isRight)

import           Text.Parsec
import           Text.Parsec.String

import           Parser.Internal
import           Parser.Types

shouldSucceed :: (Show a, Eq a) => Parser a -> String -> IO ()
shouldSucceed parser input = input `shouldSatisfy` succeeds parser

shouldFail :: (Show a, Eq a) => Parser a -> String -> IO ()
shouldFail parser input = input `shouldNotSatisfy` succeeds parser

succeeds :: (Show a, Eq a) => Parser a -> String -> Bool
succeeds parser input = isRight $ parseWithoutSource (parser >> eof) input

fails :: (Show a, Eq a) => Parser a -> String -> Bool
fails parser input = not $ succeeds parser input

testInputSource :: String
testInputSource = "Test input"

parseShouldSucceedAs :: (Show a, Eq a) => Parser a -> String -> a -> IO ()
parseShouldSucceedAs parser input a = parseFromSource parser testInputSource input `shouldBe` Right a

parseShouldBe :: (Show a, Eq a) => Parser a -> String -> Either ParseError a -> IO ()
parseShouldBe parser input result = parseFromSource parser testInputSource input `shouldBe` result

parseWithoutSource :: Parser a -> String -> Either ParseError a
parseWithoutSource parser input = parseFromSource parser testInputSource input
