-- | Alegbraic data types for OSC datum and packets.
module Sound.OSC.Type where

import qualified Data.ByteString.Lazy as B {- bytestring -}
import Data.Int {- base -}
import Data.List {- base -}
import Data.Word {- base -}

-- * Time

-- | @NTP@ time in real-valued (fractional) form.
type Time = Double

-- | Constant indicating a bundle to be executed immediately.
immediately :: Time
immediately = 1 / 2^(32::Int)

-- * String

-- | ASCII string.
newtype ASCII = ASCII [Word8]
    deriving (Eq,Show,Read)

-- | Translate from 'String' to 'ASCII'.  Out of range characters are
-- replaced with @?@.
--
-- > ascii_to_string (string_to_ascii "αβ") == "??"
-- > ascii_to_string (string_to_ascii "ab") == "ab"
string_to_ascii :: String -> ASCII
string_to_ascii =
    let f n = if n < 0x20 || n > 0x73 then 0x3f else n
    in ASCII . map (f . fromIntegral . fromEnum)

-- | Translate from 'ASCII' to 'String'.
ascii_to_string :: ASCII -> String
ascii_to_string (ASCII l) = map (toEnum . fromIntegral) l

-- * Datum

-- | Type enumerating Datum categories.
type Datum_Type = Char

-- | Four-byte midi message.
newtype MIDI = MIDI (Word8,Word8,Word8,Word8)
    deriving (Eq,Show,Read)

-- | The basic elements of OSC messages.
data Datum = Int32 {d_int32 :: Int32}
           | Int64 {d_int64 :: Int64}
           | Float {d_float :: Float}
           | Double {d_double :: Double}
           | ASCII_String {d_ascii_string :: ASCII}
           | Blob {d_blob :: B.ByteString}
           | TimeStamp {d_timestamp :: Time}
           | Midi {d_midi :: MIDI}
             deriving (Eq,Read,Show)

-- | Class for transating to and from 'Datum'.
--
-- > d_put (1::Int32) == Int32 1
-- > d_put (1::Int64) == Int64 1
-- > d_put (1::Float) == Float 1
-- > d_put (1::Double) == Double 1
-- > d_put (ASCII [0x20,0x20]) == ASCII_String (ASCII [0x20,0x20])
-- > d_put (B.pack [37,37]) == Blob (B.pack [37,37])
-- > d_put (MIDI (0,0,0,0)) == Midi (MIDI (0,0,0,0))
class Datem a where
    d_put :: a -> Datum
    d_get :: Datum -> Maybe a

instance Datem Int32 where
    d_put = Int32
    d_get d = case d of {Int32 x -> Just x;_ -> Nothing}

instance Datem Int64 where
    d_put = Int64
    d_get d = case d of {Int64 x -> Just x;_ -> Nothing}

instance Datem Float where
    d_put = Float
    d_get d = case d of {Float x -> Just x;_ -> Nothing}

instance Datem Double where
    d_put = Double
    d_get d = case d of {Double x -> Just x;_ -> Nothing}

instance Datem ASCII where
    d_put = ASCII_String
    d_get d = case d of {ASCII_String x -> Just x;_ -> Nothing}

instance Datem B.ByteString where
    d_put = Blob
    d_get d = case d of {Blob x -> Just x;_ -> Nothing}

instance Datem MIDI where
    d_put = Midi
    d_get d = case d of {Midi x -> Just x;_ -> Nothing}

-- | Type generalised 'Int32'.
--
-- > int32 (1::Int32) == int32 (1::Integer)
-- > d_int32 (int32 (maxBound::Int32)) == maxBound
-- > int32 (((2::Int) ^ (64::Int))::Int) == Int32 0
int32 :: Integral n => n -> Datum
int32 = Int32 . fromIntegral

-- | Type generalised 'Int32'.
--
-- > int64 (1::Int32) == int64 (1::Integer)
-- > d_int64 (int64 (maxBound::Int64)) == maxBound
int64 :: Integral n => n -> Datum
int64 = Int64 . fromIntegral

-- | Type generalised 'Float'.
--
-- > float (1::Int) == float (1::Double)
-- > floatRange (undefined::Float) == (-125,128)
-- > isInfinite (d_float (float (encodeFloat 1 256 :: Double))) == True
float :: Real n => n -> Datum
float = Float . realToFrac

-- | Type generalised 'Double'.
--
-- > double (1::Int) == double (1::Double)
-- > double (encodeFloat 1 256 :: Double) == Double 1.157920892373162e77
double :: Real n => n -> Datum
double = Double . realToFrac

-- | Type generalised 'ASCII_String'.
--
-- > string "string" == ASCII_String (ASCII [115,116,114,105,110,103])
string :: Enum n => [n] -> Datum
string = ASCII_String . ASCII . map (fromIntegral . fromEnum)

-- | 'Midi' of 'MIDI'.
midi :: (Word8,Word8,Word8,Word8) -> Datum
midi = Midi . MIDI

-- | Type specialised 'd_get'.
--
-- > map datum_int32 [Int32 1,Float 1] == [Just 1,Nothing]
datum_int32 :: Datum -> Maybe Int32
datum_int32 = d_get

-- | Type specialised 'd_get'.
datum_int64 :: Datum -> Maybe Int64
datum_int64 = d_get

-- | Type specialised 'd_get'.
datum_float :: Datum -> Maybe Float
datum_float = d_get

-- | Type specialised 'd_get'.
datum_double :: Datum -> Maybe Double
datum_double = d_get

-- | Type specialised 'd_get'.
datum_ascii :: Datum -> Maybe ASCII
datum_ascii = d_get

-- | 'ascii_to_string' of 'd_get'.
datum_string :: Datum -> Maybe String
datum_string = fmap ascii_to_string . d_get

-- | Type specialised 'd_get'.
datum_blob :: Datum -> Maybe B.ByteString
datum_blob = d_get

-- | 'Maybe' variant of 'd_timestamp'.
datum_timestamp :: Datum -> Maybe Time
datum_timestamp d = case d of {TimeStamp x -> Just x;_ -> Nothing}

-- | Type specialised 'd_get'.
datum_midi :: Datum -> Maybe MIDI
datum_midi = d_get

-- | 'Datum' as 'Integral' if 'Int32', 'Int64', 'Float' or 'Double'.
--
-- > let d = [Int32 5,Int64 5,Float 5.5,Double 5.5]
-- > in map datum_integral d == [Just (5::Int),Just 5,Nothing,Nothing]
datum_integral :: Integral i => Datum -> Maybe i
datum_integral d =
    case d of
      Int32 x -> Just (fromIntegral x)
      Int64 x -> Just (fromIntegral x)
      _ -> Nothing

-- | 'Datum' as 'Floating' if 'Int32', 'Int64', 'Float' or 'Double'.
--
-- > let d = [Int32 5,Int64 5,Float 5,Double 5]
-- > in Data.Maybe.mapMaybe datum_floating d == replicate 4 (5::Double)
datum_floating :: Floating n => Datum -> Maybe n
datum_floating d =
    case d of
      Int32 n -> Just (fromIntegral n)
      Int64 n -> Just (fromIntegral n)
      Float n -> Just (realToFrac n)
      Double n -> Just (realToFrac n)
      _ -> Nothing

-- | 'Datum' as sequence of 'Int' if 'String', 'Blob' or 'Midi'.
--
-- > let d = [string "5",Blob (B.pack [53]),midi (0x00,0x90,0x40,0x60)]
-- > in Data.Maybe.mapMaybe datum_sequence d == [[53],[53],[0,144,64,96]]
datum_sequence :: Datum -> Maybe [Word8]
datum_sequence d =
    case d of
      ASCII_String (ASCII s) -> Just (map (fromIntegral . fromEnum) s)
      Blob s -> Just (B.unpack s)
      Midi (MIDI (p,q,r,s)) -> Just [p,q,r,s]
      _ -> Nothing

-- | Single character identifier of an OSC datum.
datum_tag :: Datum -> Datum_Type
datum_tag dt =
    case dt of
      Int32 _ -> 'i'
      Int64 _ -> 'h'
      Float _ -> 'f'
      Double _ -> 'd'
      ASCII_String _ -> 's'
      Blob _ -> 'b'
      TimeStamp _ -> 't'
      Midi _ -> 'm'

-- * Message

-- | OSC address pattern.  This is strictly an ASCII value, but it is
-- very common to pattern match on addresses.
type Address_Pattern = String

-- | An OSC message.
data Message = Message {messageAddress :: Address_Pattern
                       ,messageDatum :: [Datum]}
               deriving (Eq,Read,Show)

-- | 'Message' constructor.  It is an 'error' if the 'Address_Pattern'
-- doesn't conform to the OSC specification.
message :: Address_Pattern -> [Datum] -> Message
message a xs =
    case a of
      '/':_ -> Message a xs
      _ -> error "message: ill-formed address pattern"

-- | Message argument types are given by a descriptor.
--
-- > ascii_to_string (descriptor [Int32 1,Float 1,string "1"]) == ",ifs"
descriptor :: [Datum] -> ASCII
descriptor l = string_to_ascii (',' : map datum_tag l)

-- | Descriptor tags are @comma@ prefixed.
descriptor_tags :: ASCII -> ASCII
descriptor_tags (ASCII l) = ASCII (drop 1 l)

-- * Bundle

-- | An OSC bundle.
data Bundle = Bundle {bundleTime :: Time
                     ,bundleMessages :: [Message]}
              deriving (Eq,Read,Show)

-- | OSC 'Bundle's can be ordered (time ascending).
instance Ord Bundle where
    compare (Bundle a _) (Bundle b _) = compare a b

-- | 'Bundle' constructor. It is an 'error' if the 'Message' list is
-- empty.
bundle :: Time -> [Message] -> Bundle
bundle t xs =
    case xs of
      [] -> error "bundle: empty?"
      _ -> Bundle t xs

-- * Packet

-- | An OSC 'Packet' is either a 'Message' or a 'Bundle'.
data Packet = Packet_Message {packetMessage :: Message}
            | Packet_Bundle {packetBundle :: Bundle}
              deriving (Eq,Read,Show)

-- | 'Packet_Bundle' '.' 'bundle'.
p_bundle :: Time -> [Message] -> Packet
p_bundle t = Packet_Bundle . bundle t

-- | 'Packet_Message' '.' 'message'.
p_message :: Address_Pattern -> [Datum] -> Packet
p_message a = Packet_Message . message a

-- | The 'Time' of 'Packet', if the 'Packet' is a 'Message' this is
-- 'immediately'.
packetTime :: Packet -> Time
packetTime = at_packet (const immediately) bundleTime

-- | Retrieve the set of 'Message's from a 'Packet'.
packetMessages :: Packet -> [Message]
packetMessages = at_packet return bundleMessages

-- | If 'Packet' is a 'Message' add 'immediately' timestamp, else 'id'.
packet_to_bundle :: Packet -> Bundle
packet_to_bundle = at_packet (\m -> Bundle immediately [m]) id

-- | If 'Packet' is a 'Message' or a 'Bundle' with an /immediate/ time
-- tag and with one element, return the 'Message', else 'Nothing'.
packet_to_message :: Packet -> Maybe Message
packet_to_message p =
    case p of
      Packet_Bundle b ->
          case b of
            Bundle t [m] -> if t == immediately then Just m else Nothing
            _ -> Nothing
      Packet_Message m -> Just m

-- | Is 'Packet' immediate, ie. a 'Bundle' with timestamp
-- 'immediately', or a plain Message.
packet_is_immediate :: Packet -> Bool
packet_is_immediate = (== immediately) . packetTime

-- | Variant of 'either' for 'Packet'.
at_packet :: (Message -> a) -> (Bundle -> a) -> Packet -> a
at_packet f g p =
    case p of
      Packet_Message m -> f m
      Packet_Bundle b -> g b

-- * Address Query

-- | Does 'Message' have the specified 'Address_Pattern'.
message_has_address :: Address_Pattern -> Message -> Bool
message_has_address x = (== x) . messageAddress

-- | Do any of the 'Message's at 'Bundle' have the specified
-- 'Address_Pattern'.
bundle_has_address :: Address_Pattern -> Bundle -> Bool
bundle_has_address x = any (message_has_address x) . bundleMessages

-- | Does 'Packet' have the specified 'Address_Pattern', ie.
-- 'message_has_address' or 'bundle_has_address'.
packet_has_address :: Address_Pattern -> Packet -> Bool
packet_has_address x =
    at_packet (message_has_address x)
              (bundle_has_address x)

-- * Pretty printing

-- | Pretty printer for 'Time'.
timePP :: Time -> String
timePP = (:) 'N' . show

-- | Pretty printer for vectors.
--
-- > vecPP [1::Int,2,3] == "<1,2,3>"
vecPP :: Show a => [a] -> String
vecPP v = '<' : intercalate "," (map show v) ++ ">"

-- | Pretty printer for 'Datum'.
--
-- > let d = [Int32 1,Float 1.2,string "str",midi (0,0x90,0x40,0x60)]
-- > in map datumPP d ==  ["1","1.2","\"str\"","<0,144,64,96>"]
datumPP :: Datum -> String
datumPP d =
    case d of
      Int32 n -> show n
      Int64 n -> show n
      Float n -> show n
      Double n -> show n
      ASCII_String s -> show (ascii_to_string s)
      Blob s -> show s
      TimeStamp t -> timePP t
      Midi (MIDI (p,q,r,s)) -> vecPP [p,q,r,s]

-- | Pretty printer for 'Message'.
messagePP :: Message -> String
messagePP (Message a d) =
    let d' = map datumPP d
    in unwords ("#message" : a : d')

-- | Pretty printer for 'Bundle'.
bundlePP :: Bundle -> String
bundlePP (Bundle t m) =
    let m' = intersperse ";" (map messagePP m)
    in unwords ("#bundle" : timePP t : m')

-- | Pretty printer for 'Packet'.
packetPP :: Packet -> String
packetPP p =
    case p of
      Packet_Message m -> messagePP m
      Packet_Bundle b -> bundlePP b

-- * Parser

-- | Variant of 'read'.
readMaybe :: (Read a) => String -> Maybe a
readMaybe s =
    case reads s of
      [(x, "")] -> Just x
      _ -> Nothing

-- | Given 'Datum_Type' attempt to parse 'Datum' at 'String'.
--
-- > parse_datum 'i' "42" == Just (Int32 42)
-- > parse_datum 'h' "42" == Just (Int64 42)
-- > parse_datum 'f' "3.14159" == Just (Float 3.14159)
-- > parse_datum 'd' "3.14159" == Just (Double 3.14159)
-- > parse_datum 's' "\"pi\"" == Just (string "pi")
-- > parse_datum 'b' "pi" == Just (Blob (B.pack [112,105]))
-- > parse_datum 'm' "(0,144,60,90)" == Just (midi (0,144,60,90))
parse_datum :: Datum_Type -> String -> Maybe Datum
parse_datum ty =
    case ty of
      'i' -> fmap Int32 . readMaybe
      'h' -> fmap Int64 . readMaybe
      'f' -> fmap Float . readMaybe
      'd' -> fmap Double . readMaybe
      's' -> fmap (ASCII_String . string_to_ascii) . readMaybe
      'b' -> Just . Blob . B.pack . map (fromIntegral . fromEnum)
      't' -> error "parse_datum: timestamp"
      'm' -> fmap midi . readMaybe
      _ -> error "parse_datum: type"
