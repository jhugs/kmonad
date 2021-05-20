-- NOTE: We disable the orphans warning because we define the 'Display' instance
-- for 'Keycode' here, instead of per OS.
{-# OPTIONS_GHC -Wno-orphans #-}
module KMonad.Util.Keyboard.Types
  ( -- * $switch
    Switch(..)
  , HasSwitch(..)

    -- * $code
  , Keycode
  , HasCode(..)

    -- * $name
  , NoSuchKeynameException(..)
  , nameKeycodes
  , kn

    -- * $keyswitch
  , KeySwitch
  , HasKeySwitch(..)
  , mkKeySwitch

    -- * $keyevent
  , KeyEvent
  , mkKeyEvent

    -- * $io
  , GetKey
  , PutKey

    -- * Reexports
  , module X

  )
where

import KMonad.Prelude
import KMonad.Util.Name
import KMonad.Util.Time
import KMonad.Util.Keyboard.OS (Keycode, keycodeNames)

import KMonad.Util.Keyboard.Common as X
import qualified RIO.HashMap       as M

--------------------------------------------------------------------------------
-- $switch

-- | Differentiates between 'Press' and 'Release' events
data Switch
  = Press
  | Release
  deriving (Eq, Show)

-- | A class describing how to get at somethign containing a 'Switch'
class HasSwitch a where switch :: Lens' a Switch
instance HasSwitch Switch where switch = id

--------------------------------------------------------------------------------
-- $code
--
-- NOTE: OS-specific 'Keycode' type imported from separate module

-- | A class describing how to get at something containing a 'Keycode'
class HasCode a where code :: Lens' a Keycode
instance HasCode Keycode where code = id


--------------------------------------------------------------------------------
-- $name

-- | The error that is thrown when we encounter an unknown Keyname.
data NoSuchKeynameException = NoSuchKeynameException Name deriving Show
instance Exception NoSuchKeynameException where
  displayException (NoSuchKeynameException n) =
    "Encountered unknown keyname in code: " <> unpack n

-- | Reversed map from 'Keycode' to 'Keyname'
nameKeycodes :: M.HashMap Keycode CoreName
nameKeycodes = reverseMap keycodeNames

-- | Look up the name for a given 'Keycode'
--
-- Unlike `kc` which does the reverse lookup, and will error when attempting to
-- access an unknown key, we anticipate that we will encounter codes that we
-- have no name for (generated by the OS). Therefore this lookup function uses
-- 'Maybe'
kn :: Keycode -> Maybe CoreName
kn = flip M.lookup nameKeycodes

instance Display Keycode where
  textDisplay c = fromMaybe (tshow c) (textDisplay <$> kn c)
 
--------------------------------------------------------------------------------
-- $keyswitch

-- | Record indicating a switch-change for a particular keycode
data KeySwitch = KeySwitch
  { _kSwitch :: Switch
  , _kCode   :: Keycode
  } deriving (Eq, Show)
makeLenses ''KeySwitch

instance Display KeySwitch where
  textDisplay (KeySwitch Press   c) = "Press "   <> textDisplay c
  textDisplay (KeySwitch Release c) = "Release " <> textDisplay c


class HasKeySwitch a where keySwitch :: Lens' a KeySwitch

instance HasKeySwitch KeySwitch where keySwitch = id
instance HasSwitch    KeySwitch where switch    = kSwitch
instance HasCode      KeySwitch where code      = kCode

-- | Constructor used to make 'KeySwitch' data
mkKeySwitch :: Switch -> Keycode -> KeySwitch
mkKeySwitch = KeySwitch

--------------------------------------------------------------------------------
-- $keyevent

-- | The event of some switch for some keycode at some time.
data KeyEvent = KeyEvent
  { _eKeySwitch :: KeySwitch
  , _eTime      :: Time
  } deriving (Eq, Show)
makeLenses ''KeyEvent

-- | TODO: make me nice
instance Display KeyEvent where textDisplay = tshow

instance HasKeySwitch KeyEvent where keySwitch = eKeySwitch
instance HasSwitch    KeyEvent where switch    = keySwitch.switch
instance HasCode      KeyEvent where code      = keySwitch.code
instance HasTime      KeyEvent where time      = eTime

-- | A constructor for new 'KeyEvent's
mkKeyEvent :: Switch -> Keycode -> Time -> KeyEvent
mkKeyEvent s c = KeyEvent (KeySwitch s c)

--------------------------------------------------------------------------------
-- $io
--
-- Generally useful types for IO

-- | Alias for an action that fetches a (Switch, Keycode) tuple from the OS.
type GetKey = OnlyIO KeySwitch

-- | Alias for an action that sends (Switch, Keycode) tuples to the OS.
type PutKey = KeySwitch -> OnlyIO ()
