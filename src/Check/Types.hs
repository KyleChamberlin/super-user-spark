module Check.Types where

import           CoreTypes
import           Data.Digest.Pure.MD5 (MD5Digest)

type HashDigest = MD5Digest

data Diagnostics
    = Nonexistent
    | IsFile
    | IsDirectory
    | IsLinkTo FilePath
    | IsWeird
    deriving (Show, Eq)

data DiagnosedFp = D
    { diagnosedFilePath    :: FilePath
    , diagnosedDiagnostics :: Diagnostics
    , diagnosedHashDigest  :: HashDigest
    } deriving (Show, Eq)

data Instruction = Instruction FilePath FilePath DeploymentKind
    deriving (Show, Eq)

data CleanupInstruction
    = CleanFile FilePath
    | CleanDirectory FilePath
    | CleanLink FilePath
    deriving (Show, Eq)

data DeploymentCheckResult
    = DeploymentDone                                        -- ^ Done already
    | ReadyToDeploy Instruction                             -- ^ Immediately possible
    | DirtySituation String Instruction CleanupInstruction  -- ^ Possible after cleanup of destination
    | ImpossibleDeployment [String]                         -- ^ Entirely impossible
    deriving (Show, Eq)

data CheckResult
    = AlreadyDone                                   -- ^ Done already
    | Ready Instruction                             -- ^ Immediately possible
    | Dirty String Instruction CleanupInstruction   -- ^ Possible after cleanup
    | Impossible String                             -- ^ Entirely impossible
    deriving (Show, Eq)

data DiagnosedDeployment = Diagnosed
    { diagnosedSrcs :: [DiagnosedFp]
    , diagnosedDst  :: DiagnosedFp
    , diagnosedKind :: DeploymentKind
    } deriving (Show, Eq)

