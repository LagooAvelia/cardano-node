module Cardano.Logging.TraceDispatcherMessage
  (
    UnknownNamespaceKind (..)
  , TraceDispatcherMessage (..)
  ) where

import           Data.Aeson hiding (Error)
import qualified Data.Map as Map
import           Data.Text

import           Cardano.Logging.Types

data UnknownNamespaceKind =
    UKFSeverity
  | UKFPrivacy
  | UKFDetails

instance Show UnknownNamespaceKind where
  show UKFSeverity = "severity"
  show UKFPrivacy = "privacy"
  show UKFDetails = "details"

data TraceDispatcherMessage =
    StartLimiting Text
    -- ^ This message indicates the start of frequency limiting
  | StopLimiting Text Int
    -- ^ This message indicates the stop of frequency limiting,
    -- and gives the number of messages that has been suppressed
  | RememberLimiting Text Int
    -- ^ This message remembers of ongoing frequency limiting,
    -- and gives the number of messages that has been suppressed
  | UnknownNamespace [Text] [Text] UnknownNamespaceKind
    -- ^ An internal error was detected
  | TracerInfo [Text] [Text] [Text]
    -- ^  The first array signifies the namespace of silent tracers
    --    The second array signifies the namespace tracers without metrics
    --    The third array gives the names of all tracers
  | MetricsInfo (Map.Map Text Int)
    -- ^  Outputs optional statistics about metrics frequency

  deriving Show

instance LogFormatting TraceDispatcherMessage where
  forHuman (StartLimiting txt) = "Start of frequency limiting for " <> txt
  forHuman (StopLimiting txt num) = "Stop of frequency limiting for " <> txt <>
    ". Suppressed " <> pack (show num) <> " messages."
  forHuman (RememberLimiting txt num) = "Frequency limiting still active for " <> txt <>
    ". Suppressed so far " <> pack (show num) <> " messages."
  forHuman (UnknownNamespace nsPrefixNS nsInnerNS qk) = "Unknown namespace detected "
    <> intercalate (singleton '.') (nsPrefixNS ++ nsInnerNS)
    <> ". Used for querying " <> (pack . show) qk <> "."
  forHuman (TracerInfo silent noMetrics allTracers) = "The tracing system has silent the following tracer,"
    <> " as they will never have any output according to the current config: "
    <> intercalate (singleton ' ') silent <> ". The following tracers will not emit metrics "
    <> intercalate (singleton ' ') noMetrics <> ". Here is a complete list of all tracers: "
    <> intercalate (singleton ' ') allTracers <> "."
  forHuman (MetricsInfo mmap) = "Number of metrics delivered, " <> (pack . show) mmap

  forMachine _dtl StartLimiting {} = mconcat
        [ "kind" .= String "StartLimiting"
        ]
  forMachine _dtl (StopLimiting _txt num) = mconcat
        [ "kind" .= String "StopLimiting"
        , "numSuppressed" .= Number (fromIntegral num)
        ]
  forMachine _dtl (RememberLimiting _txt num) = mconcat
        [ "kind" .= String "RememberLimiting"
        , "numSuppressed" .= Number (fromIntegral num)
        ]
  forMachine _dtl (UnknownNamespace nsun nsleg query) = mconcat
        [ "kind" .= String "UnknownNamespace"
        , "unknownNamespace" .= String (intercalate (singleton '.') nsun)
        , "legalNamespace" .= String (intercalate (singleton '.') nsleg)
        , "querying" .= String ((pack . show) query)
        ]
  forMachine _dtl (TracerInfo silent noMetrics allTracers) = mconcat
        [ "kind" .= String "TracerMeta"
        , "silentTracers" .= String (intercalate (singleton ' ') silent)
        , "noMetrics" .= String (intercalate (singleton ' ') noMetrics)
        , "allTracers" .= String (intercalate (singleton ' ') allTracers)
        ]
  forMachine _dtl (MetricsInfo mmap) = mconcat
        [ "kind" .= String "MetricsInfo"
        , "metrics count" .= String ((pack . show) mmap)
        ]

  asMetrics StartLimiting {} = []
  asMetrics (StopLimiting txt num)  = [IntM
                                        ("SuppressedMessages " <> txt)
                                        (fromIntegral num)]
  asMetrics RememberLimiting {} = []
  asMetrics UnknownNamespace {} = []
  asMetrics TracerInfo {}       = []
  asMetrics MetricsInfo {}       = []

instance MetaTrace TraceDispatcherMessage where
    namespaceFor StartLimiting {}    = Namespace [] ["StartLimiting"]
    namespaceFor StopLimiting {}     = Namespace [] ["StopLimiting"]
    namespaceFor RememberLimiting {} = Namespace [] ["RememberLimiting"]
    namespaceFor UnknownNamespace {} = Namespace [] ["UnknownNamespace"]
    namespaceFor TracerInfo {}       = Namespace [] ["TracerInfo"]
    namespaceFor MetricsInfo {}       = Namespace [] ["MetricsInfo"]


    severityFor (Namespace _ ["StartLimiting"]) _    = Just Notice
    severityFor (Namespace _ ["StopLimiting"]) _     = Just Notice
    severityFor (Namespace _ ["RememberLimiting"]) _ = Just Notice
    severityFor (Namespace _ ["UnknownNamespace"]) _ = Just Error
    severityFor (Namespace _ ["TracerInfo"]) _       = Just Notice
    severityFor (Namespace _ ["MetricsInfo"]) _      = Just Debug
    severityFor _ _                                  = Nothing


    documentFor (Namespace _ ["StartLimiting"])    = Just
      "This message indicates the start of frequency limiting"
    documentFor (Namespace _ ["StopLimiting"])     = Just $ mconcat
      [ "This message indicates the stop of frequency limiting,"
      , " and gives the number of messages that has been suppressed"
      ]
    documentFor (Namespace _ ["RememberLimiting"]) = Just $ mconcat
      [ "^ This message remembers of ongoing frequency limiting,"
      , " and gives the number of messages that has been suppressed"
      ]
    documentFor (Namespace _ ["UnknownNamespace"]) = Just $ mconcat
      [ "A value was queried for a namespaces from a tracer,"
      , "which is unknown. This inicates a bug in the tracer implementation."
      ]
    documentFor (Namespace _ ["TracerInfo"]) = Just $ mconcat
      [ "Writes out tracers with metrics and silent tracers."
      ]
    documentFor (Namespace _ ["MetricsInfo"]) = Just $ mconcat
      [ "Writes out number of metrics delivered."
      ]
    documentFor _ = Nothing


    allNamespaces = [
        Namespace [] ["StartLimiting"]
      , Namespace [] ["StopLimiting"]
      , Namespace [] ["RememberLimiting"]
      , Namespace [] ["UnknownNamespace"]
      , Namespace [] ["TracerInfo"]
      , Namespace [] ["MetricsInfo"]
      ]
