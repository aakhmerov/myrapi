{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RecordWildCards #-}

module Main where

import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy.Char8 as B8L
import           Data.Monoid
import qualified Data.Text as T
import           Myracloud
import           Myracloud.Commands
import           Myracloud.Commands.Util
import           Myracloud.Types hiding (value)
import           Options.Applicative
import           Servant.Common.BaseUrl
import           System.Exit
import           System.IO (stdout)

data Options = Options
  { optGlobalCredentials :: Credentials
  , optGlobalBaseUrl :: BaseUrl
  , optCommand :: Command
  } deriving (Show, Eq)

data Command = Create T.Text DnsRecordCreate
             | List DnsListOptions
             | ListAll DnsListOptions
             | Delete T.Text DnsRecordDelete
             | Update T.Text DnsRecordUpdate
             | Search T.Text DnsSearchOptions
             deriving (Show, Eq)

commandOptions :: Parser Command
commandOptions = subparser $
  (command "create" (info (Create <$> domainOption <*> dnsCreateOptions)
                     (progDesc "Create a record for a domain")))
 <>
  (command "list" (info (List <$> dnsListOptions)
                   (progDesc "List records for a domain")))
 <>
  (command "delete" (info (Delete <$> domainOption <*> dnsDeleteOptions)
                     (progDesc "Delete records for a domain")))
 <>
  (command "update" (info (Update <$> domainOption <*> dnsUpdateOptions)
                     (progDesc "Update records for a domain")))
 <>
  (command "search" (info (Search <$> domainOption <*> dnsSearchOptions)
                     (progDesc "Search for records for specific subdomain")))


globalOptions :: Parser Options
globalOptions = Options
  <$> credentialsOption
  <*> baseUrlOption
  <*> commandOptions

opts :: ParserInfo Options
opts = info (helper <*> globalOptions)
       (fullDesc <> progDesc "Command line interface to MYRACLOUD")

exit :: (IsSuccessful b, Show a, A.ToJSON b) => Either a (Result b) -> IO ()
exit (Left x) = putStrLn ("ERROR: Failed with " <> show x) >> exitFailure
exit (Right x) = B8L.hPutStrLn stdout (A.encode x) >> case x of
  Myracloud.Types.Success r | isSuccessful r -> exitSuccess
                            | otherwise -> exitFailure
  Myracloud.Types.Failure _ -> exitFailure

wip :: IO ()
wip = putStrLn . mconcat $
  [ "Warning: there is something wrong with this feature, use"
  , " at your own risk and pay attention to the output!"
  ]

main :: IO ()
main = execParser opts >>= \case
  Options creds baseUrl com -> case com of
    Create s r -> runCreate creds r (Site s) baseUrl >>= exit
    List (DnsListOptions {..}) -> case dnsListPage of
      Nothing -> runListAll creds dnsListSite baseUrl >>= exit
      Just p -> runList creds dnsListSite p baseUrl >>= exit
    -- TODO: Due to servant-client limitation, the return type of
    -- runDelete is just dummy unit
    Delete s r -> wip >> runDelete creds r (Site s) baseUrl >>= exit
    Update s r -> runUpdate creds r (Site s) baseUrl >>= exit
    Search s (DnsSearchOptions {..}) ->
      search creds (Site s) baseUrl dnsSearchPage (Site dnsSearchSubdomain)
      >>= exit
