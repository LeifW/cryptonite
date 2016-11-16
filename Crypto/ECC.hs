-- |
-- Module      : Crypto.ECC
-- License     : BSD-style
-- Maintainer  : Vincent Hanquez <vincent@snarc.org>
-- Stability   : experimental
-- Portability : unknown
--
-- Elliptic Curve Cryptography
--
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}
module Crypto.ECC
    ( Curve_P256R1(..)
    , Curve_P384R1(..)
    , Curve_P521R1(..)
    , Curve_X25519(..)
    , EllipticCurve(..)
    , EllipticCurveDH(..)
    , EllipticCurveArith(..)
    , KeyPair(..)
    , SharedSecret(..)
    ) where

import qualified Crypto.PubKey.ECC.P256 as P256
import qualified Crypto.PubKey.ECC.Types as H
import qualified Crypto.PubKey.ECC.Prim as H
import           Crypto.Random
import           Crypto.Internal.Imports
import           Crypto.Internal.ByteArray (ByteArrayAccess, ScrubbedBytes)
import           Crypto.Number.Serialize (i2ospOf_)
import qualified Crypto.PubKey.Curve25519 as X25519
import           Data.Function (on)
import           Data.ByteArray (convert)

-- | An elliptic curve key pair composed of the private part (a scalar), and
-- the associated point.
data KeyPair curve = KeyPair
    { keypairGetPublic  :: !(Point curve)
    , keypairGetPrivate :: !(Scalar curve)
    }

newtype SharedSecret = SharedSecret ScrubbedBytes
    deriving (Eq, ByteArrayAccess)

class EllipticCurve curve where
    -- | Point on an Elliptic Curve
    data Point curve  :: *

    -- | Scalar in the Elliptic Curve domain
    data Scalar curve :: *

    -- | get the order of the Curve
    curveGetOrder :: curve -> Integer

    -- | get the curve related to a point on a curve
    curveOfPoint :: Point curve -> curve

    -- | get the curve related to a curve's scalar
    curveOfScalar :: Scalar curve -> curve

    -- | get the base point of the Curve
    curveGetBasePoint :: Point curve

    -- | Generate a new random scalar on the curve.
    -- The scalar will represent a number between 1 and the order of the curve non included
    curveGenerateScalar :: MonadRandom randomly => randomly (Scalar curve)

    -- | Generate a new random keypair
    curveGenerateKeyPair :: MonadRandom randomly => randomly (KeyPair curve)

class EllipticCurve curve => EllipticCurveDH curve where
    -- | Generate a Diffie hellman secret value.
    --
    -- This is generally just the .x coordinate of the resulting point, that
    -- is not hashed.
    --
    -- use `pointSmul` to keep the result in Point format.
    ecdh :: Scalar curve -> Point curve -> SharedSecret

class EllipticCurve curve => EllipticCurveArith curve where
    -- | Add points on a curve
    pointAdd :: Point curve -> Point curve -> Point curve

    -- | Scalar Multiplication on a curve
    pointSmul :: Scalar curve -> Point curve -> Point curve

--   -- | Scalar Inverse
--   scalarInverse :: Scalar curve -> Scalar curve

-- | P256 Curve
--
-- also known as P256
data Curve_P256R1 = Curve_P256R1

instance EllipticCurve Curve_P256R1 where
    newtype Point Curve_P256R1 = P256Point { unP256Point :: P256.Point }
    newtype Scalar Curve_P256R1 = P256Scalar { unP256Scalar :: P256.Scalar }
    curveGetOrder     _ = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551
    curveGetBasePoint = P256Point P256.pointBase
    curveOfScalar _ = Curve_P256R1
    curveOfPoint _ = Curve_P256R1
    curveGenerateScalar = P256Scalar <$> P256.scalarGenerate
    curveGenerateKeyPair = toKeyPair <$> P256.scalarGenerate
      where toKeyPair scalar = KeyPair (P256Point $ P256.toPoint scalar) (P256Scalar scalar)

instance EllipticCurveArith Curve_P256R1 where
    pointAdd  a b = P256Point $ (P256.pointAdd `on` unP256Point) a b
    pointSmul s p = P256Point $ P256.pointMul (unP256Scalar s) (unP256Point p)

instance EllipticCurveDH Curve_P256R1 where
    ecdh s p = shared
      where
        (x, _) = P256.pointToIntegers $ unP256Point $ pointSmul s p
        len = (256 + 7) `div` 8
        shared = SharedSecret $ i2ospOf_ len x

data Curve_P384R1 = Curve_P384R1

instance EllipticCurve Curve_P384R1 where
    newtype Point Curve_P384R1 = P384Point { unP384Point :: H.Point }
    newtype Scalar Curve_P384R1 = P384Scalar { unP384Scalar :: H.PrivateNumber }
    curveGetOrder _ = H.ecc_n $ H.common_curve $ H.getCurveByName H.SEC_p384r1
    curveGetBasePoint = P384Point $ H.ecc_g $ H.common_curve $ H.getCurveByName H.SEC_p384r1
    curveOfScalar _ = Curve_P384R1
    curveOfPoint _ = Curve_P384R1
    curveGenerateScalar = P384Scalar <$> H.scalarGenerate (H.getCurveByName H.SEC_p384r1)
    curveGenerateKeyPair = toKeyPair <$> H.scalarGenerate (H.getCurveByName H.SEC_p384r1)
      where toKeyPair scalar = KeyPair (P384Point $ H.pointBaseMul (H.getCurveByName H.SEC_p384r1) scalar) (P384Scalar scalar)

instance EllipticCurveArith Curve_P384R1 where
    pointAdd a b = P384Point $ (H.pointAdd (H.getCurveByName H.SEC_p384r1) `on` unP384Point) a b
    pointSmul s p = P384Point (H.pointMul (H.getCurveByName H.SEC_p384r1) (unP384Scalar s) (unP384Point p))

instance EllipticCurveDH Curve_P384R1 where
    ecdh s p = shared
      where
        H.Point x _ = unP384Point $ pointSmul s p
        len = (384 + 7) `div` 8
        shared = SharedSecret $ i2ospOf_ len x

data Curve_P521R1 = Curve_P521R1

instance EllipticCurve Curve_P521R1 where
    newtype Point Curve_P521R1 = P521Point { unP521Point :: H.Point }
    newtype Scalar Curve_P521R1 = P521Scalar { unP521Scalar :: H.PrivateNumber }
    curveGetOrder _ = H.ecc_n $ H.common_curve $ H.getCurveByName H.SEC_p521r1
    curveGetBasePoint = P521Point $ H.ecc_g $ H.common_curve $ H.getCurveByName H.SEC_p521r1
    curveOfScalar _ = Curve_P521R1
    curveOfPoint _ = Curve_P521R1
    curveGenerateScalar = P521Scalar <$> H.scalarGenerate (H.getCurveByName H.SEC_p521r1)
    curveGenerateKeyPair = toKeyPair <$> H.scalarGenerate (H.getCurveByName H.SEC_p521r1)
      where toKeyPair scalar = KeyPair (P521Point $ H.pointBaseMul (H.getCurveByName H.SEC_p521r1) scalar) (P521Scalar scalar)

instance EllipticCurveArith Curve_P521R1 where
    pointAdd a b = P521Point $ (H.pointAdd (H.getCurveByName H.SEC_p521r1) `on` unP521Point) a b
    pointSmul s p = P521Point (H.pointMul (H.getCurveByName H.SEC_p521r1) (unP521Scalar s) (unP521Point p))

instance EllipticCurveDH Curve_P521R1 where
    ecdh s p = shared
      where
        H.Point x _ = unP521Point $ pointSmul s p
        len = (521 + 7) `div` 8
        shared = SharedSecret $ i2ospOf_ len x

data Curve_X25519 = Curve_X25519

instance EllipticCurve Curve_X25519 where
    newtype Point Curve_X25519 = X25519Point X25519.PublicKey
    newtype Scalar Curve_X25519 = X25519Scalar X25519.SecretKey
    curveGetOrder     _ = undefined
    curveGetBasePoint = undefined
    curveOfScalar _ = Curve_X25519
    curveOfPoint _ = Curve_X25519
    curveGenerateScalar = X25519Scalar <$> X25519.generateSecretKey
    curveGenerateKeyPair = do
        s <- X25519.generateSecretKey
        let p = X25519.toPublic s
        return $ KeyPair (X25519Point p) (X25519Scalar s)

instance EllipticCurveArith Curve_X25519 where
    pointAdd  = undefined
    pointSmul = undefined

instance EllipticCurveDH Curve_X25519 where
    ecdh (X25519Scalar s) (X25519Point p) = SharedSecret $ convert secret
      where
        secret = X25519.dh p s
