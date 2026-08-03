import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $dict from "../../../gleam_stdlib/gleam/dict.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $float from "../../../gleam_stdlib/gleam/float.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $timestamp from "../../../gleam_time/gleam/time/timestamp.mjs";
import { Ok, Error, toList, Empty as $Empty, CustomType as $CustomType, isEqual } from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";
import * as $jws from "../../gose/jose/jws.mjs";

/**
 * The JWS signature did not verify against any of the provided keys.
 */
export class InvalidSignature extends $CustomType {}
export const JwtError$InvalidSignature$const = new InvalidSignature();
export const JwtError$InvalidSignature = () => JwtError$InvalidSignature$const;
export const JwtError$isInvalidSignature = (value) =>
  value instanceof InvalidSignature;

/**
 * JWE decryption failed (wrong key, corrupted ciphertext, etc.).
 */
export class DecryptionFailed extends $CustomType {
  constructor(reason) {
    super();
    this.reason = reason;
  }
}
export const JwtError$DecryptionFailed = (reason) =>
  new DecryptionFailed(reason);
export const JwtError$isDecryptionFailed = (value) =>
  value instanceof DecryptionFailed;
export const JwtError$DecryptionFailed$reason = (value) => value.reason;
export const JwtError$DecryptionFailed$0 = (value) => value.reason;

/**
 * The `exp` claim is in the past.
 */
export class TokenExpired extends $CustomType {
  constructor(expired_at) {
    super();
    this.expired_at = expired_at;
  }
}
export const JwtError$TokenExpired = (expired_at) =>
  new TokenExpired(expired_at);
export const JwtError$isTokenExpired = (value) => value instanceof TokenExpired;
export const JwtError$TokenExpired$expired_at = (value) => value.expired_at;
export const JwtError$TokenExpired$0 = (value) => value.expired_at;

/**
 * The `nbf` claim is in the future.
 */
export class TokenNotYetValid extends $CustomType {
  constructor(valid_from) {
    super();
    this.valid_from = valid_from;
  }
}
export const JwtError$TokenNotYetValid = (valid_from) =>
  new TokenNotYetValid(valid_from);
export const JwtError$isTokenNotYetValid = (value) =>
  value instanceof TokenNotYetValid;
export const JwtError$TokenNotYetValid$valid_from = (value) => value.valid_from;
export const JwtError$TokenNotYetValid$0 = (value) => value.valid_from;

/**
 * The `exp` claim is required by the verifier but absent.
 */
export class MissingExpiration extends $CustomType {}
export const JwtError$MissingExpiration$const = new MissingExpiration();
export const JwtError$MissingExpiration = () =>
  JwtError$MissingExpiration$const;
export const JwtError$isMissingExpiration = (value) =>
  value instanceof MissingExpiration;

/**
 * The `iat` claim is required by the verifier but absent.
 */
export class MissingIssuedAt extends $CustomType {}
export const JwtError$MissingIssuedAt$const = new MissingIssuedAt();
export const JwtError$MissingIssuedAt = () => JwtError$MissingIssuedAt$const;
export const JwtError$isMissingIssuedAt = (value) =>
  value instanceof MissingIssuedAt;

/**
 * The `iat` claim is in the future.
 */
export class IssuedInFuture extends $CustomType {
  constructor(issued_at) {
    super();
    this.issued_at = issued_at;
  }
}
export const JwtError$IssuedInFuture = (issued_at) =>
  new IssuedInFuture(issued_at);
export const JwtError$isIssuedInFuture = (value) =>
  value instanceof IssuedInFuture;
export const JwtError$IssuedInFuture$issued_at = (value) => value.issued_at;
export const JwtError$IssuedInFuture$0 = (value) => value.issued_at;

/**
 * The token age (now − `iat`) exceeds the configured `max_age` in seconds.
 */
export class TokenTooOld extends $CustomType {
  constructor(issued_at, max_age) {
    super();
    this.issued_at = issued_at;
    this.max_age = max_age;
  }
}
export const JwtError$TokenTooOld = (issued_at, max_age) =>
  new TokenTooOld(issued_at, max_age);
export const JwtError$isTokenTooOld = (value) => value instanceof TokenTooOld;
export const JwtError$TokenTooOld$issued_at = (value) => value.issued_at;
export const JwtError$TokenTooOld$0 = (value) => value.issued_at;
export const JwtError$TokenTooOld$max_age = (value) => value.max_age;
export const JwtError$TokenTooOld$1 = (value) => value.max_age;

/**
 * The `jti` claim is empty or otherwise invalid.
 */
export class InvalidJti extends $CustomType {
  constructor(jti) {
    super();
    this.jti = jti;
  }
}
export const JwtError$InvalidJti = (jti) => new InvalidJti(jti);
export const JwtError$isInvalidJti = (value) => value instanceof InvalidJti;
export const JwtError$InvalidJti$jti = (value) => value.jti;
export const JwtError$InvalidJti$0 = (value) => value.jti;

/**
 * The `iss` claim does not match the expected issuer.
 */
export class IssuerMismatch extends $CustomType {
  constructor(expected, actual) {
    super();
    this.expected = expected;
    this.actual = actual;
  }
}
export const JwtError$IssuerMismatch = (expected, actual) =>
  new IssuerMismatch(expected, actual);
export const JwtError$isIssuerMismatch = (value) =>
  value instanceof IssuerMismatch;
export const JwtError$IssuerMismatch$expected = (value) => value.expected;
export const JwtError$IssuerMismatch$0 = (value) => value.expected;
export const JwtError$IssuerMismatch$actual = (value) => value.actual;
export const JwtError$IssuerMismatch$1 = (value) => value.actual;

/**
 * The `aud` claim does not contain the expected audience.
 */
export class AudienceMismatch extends $CustomType {
  constructor(expected, actual) {
    super();
    this.expected = expected;
    this.actual = actual;
  }
}
export const JwtError$AudienceMismatch = (expected, actual) =>
  new AudienceMismatch(expected, actual);
export const JwtError$isAudienceMismatch = (value) =>
  value instanceof AudienceMismatch;
export const JwtError$AudienceMismatch$expected = (value) => value.expected;
export const JwtError$AudienceMismatch$0 = (value) => value.expected;
export const JwtError$AudienceMismatch$actual = (value) => value.actual;
export const JwtError$AudienceMismatch$1 = (value) => value.actual;

/**
 * The token's JWS algorithm does not match the expected algorithm.
 */
export class JwsAlgorithmMismatch extends $CustomType {
  constructor(expected, actual) {
    super();
    this.expected = expected;
    this.actual = actual;
  }
}
export const JwtError$JwsAlgorithmMismatch = (expected, actual) =>
  new JwsAlgorithmMismatch(expected, actual);
export const JwtError$isJwsAlgorithmMismatch = (value) =>
  value instanceof JwsAlgorithmMismatch;
export const JwtError$JwsAlgorithmMismatch$expected = (value) => value.expected;
export const JwtError$JwsAlgorithmMismatch$0 = (value) => value.expected;
export const JwtError$JwsAlgorithmMismatch$actual = (value) => value.actual;
export const JwtError$JwsAlgorithmMismatch$1 = (value) => value.actual;

/**
 * The token's JWE algorithm or encryption does not match expected values.
 */
export class JweAlgorithmMismatch extends $CustomType {
  constructor(expected_alg, expected_enc, actual_alg, actual_enc) {
    super();
    this.expected_alg = expected_alg;
    this.expected_enc = expected_enc;
    this.actual_alg = actual_alg;
    this.actual_enc = actual_enc;
  }
}
export const JwtError$JweAlgorithmMismatch = (expected_alg, expected_enc, actual_alg, actual_enc) =>
  new JweAlgorithmMismatch(expected_alg, expected_enc, actual_alg, actual_enc);
export const JwtError$isJweAlgorithmMismatch = (value) =>
  value instanceof JweAlgorithmMismatch;
export const JwtError$JweAlgorithmMismatch$expected_alg = (value) =>
  value.expected_alg;
export const JwtError$JweAlgorithmMismatch$0 = (value) => value.expected_alg;
export const JwtError$JweAlgorithmMismatch$expected_enc = (value) =>
  value.expected_enc;
export const JwtError$JweAlgorithmMismatch$1 = (value) => value.expected_enc;
export const JwtError$JweAlgorithmMismatch$actual_alg = (value) =>
  value.actual_alg;
export const JwtError$JweAlgorithmMismatch$2 = (value) => value.actual_alg;
export const JwtError$JweAlgorithmMismatch$actual_enc = (value) =>
  value.actual_enc;
export const JwtError$JweAlgorithmMismatch$3 = (value) => value.actual_enc;

/**
 * A `kid` header is required for key lookup but absent from the token.
 */
export class MissingKid extends $CustomType {}
export const JwtError$MissingKid$const = new MissingKid();
export const JwtError$MissingKid = () => JwtError$MissingKid$const;
export const JwtError$isMissingKid = (value) => value instanceof MissingKid;

/**
 * The token's `kid` does not match any key in the provided set.
 */
export class UnknownKid extends $CustomType {
  constructor(kid) {
    super();
    this.kid = kid;
  }
}
export const JwtError$UnknownKid = (kid) => new UnknownKid(kid);
export const JwtError$isUnknownKid = (value) => value instanceof UnknownKid;
export const JwtError$UnknownKid$kid = (value) => value.kid;
export const JwtError$UnknownKid$0 = (value) => value.kid;

/**
 * The token could not be parsed (invalid compact serialization, bad
 * base64, malformed header JSON, etc.).
 */
export class MalformedToken extends $CustomType {
  constructor(reason) {
    super();
    this.reason = reason;
  }
}
export const JwtError$MalformedToken = (reason) => new MalformedToken(reason);
export const JwtError$isMalformedToken = (value) =>
  value instanceof MalformedToken;
export const JwtError$MalformedToken$reason = (value) => value.reason;
export const JwtError$MalformedToken$0 = (value) => value.reason;

/**
 * The claims payload is valid JSON but a required field is missing or
 * has an unexpected type.
 */
export class ClaimDecodingFailed extends $CustomType {
  constructor(reason) {
    super();
    this.reason = reason;
  }
}
export const JwtError$ClaimDecodingFailed = (reason) =>
  new ClaimDecodingFailed(reason);
export const JwtError$isClaimDecodingFailed = (value) =>
  value instanceof ClaimDecodingFailed;
export const JwtError$ClaimDecodingFailed$reason = (value) => value.reason;
export const JwtError$ClaimDecodingFailed$0 = (value) => value.reason;

/**
 * A security-sensitive header (e.g. `alg`) appears in the unprotected
 * header, which is not integrity-protected.
 */
export class InsecureUnprotectedHeader extends $CustomType {
  constructor(header) {
    super();
    this.header = header;
  }
}
export const JwtError$InsecureUnprotectedHeader = (header) =>
  new InsecureUnprotectedHeader(header);
export const JwtError$isInsecureUnprotectedHeader = (value) =>
  value instanceof InsecureUnprotectedHeader;
export const JwtError$InsecureUnprotectedHeader$header = (value) =>
  value.header;
export const JwtError$InsecureUnprotectedHeader$0 = (value) => value.header;

/**
 * A claim value is invalid (empty audience list, reserved claim name, etc.).
 */
export class InvalidClaim extends $CustomType {
  constructor(reason) {
    super();
    this.reason = reason;
  }
}
export const JwtError$InvalidClaim = (reason) => new InvalidClaim(reason);
export const JwtError$isInvalidClaim = (value) => value instanceof InvalidClaim;
export const JwtError$InvalidClaim$reason = (value) => value.reason;
export const JwtError$InvalidClaim$0 = (value) => value.reason;

/**
 * An error from the underlying JOSE layer (JWS, JWE, or JWK).
 */
export class JoseError extends $CustomType {
  constructor(error) {
    super();
    this.error = error;
  }
}
export const JwtError$JoseError = (error) => new JoseError(error);
export const JwtError$isJoseError = (value) => value instanceof JoseError;
export const JwtError$JoseError$error = (value) => value.error;
export const JwtError$JoseError$0 = (value) => value.error;

class Claims extends $CustomType {
  constructor(iss, sub, aud, exp, nbf, iat, jti, custom) {
    super();
    this.iss = iss;
    this.sub = sub;
    this.aud = aud;
    this.exp = exp;
    this.nbf = nbf;
    this.iat = iat;
    this.jti = jti;
    this.custom = custom;
  }
}

class Jwt extends $CustomType {
  constructor(alg, kid, claims, claims_json, token) {
    super();
    this.alg = alg;
    this.kid = kid;
    this.claims = claims;
    this.claims_json = claims_json;
    this.token = token;
  }
}

/**
 * No kid requirement - prioritize matching keys but try all (default)
 */
export class NoKidRequirement extends $CustomType {}
export const KidPolicy$NoKidRequirement$const = new NoKidRequirement();
export const KidPolicy$NoKidRequirement = () =>
  KidPolicy$NoKidRequirement$const;
export const KidPolicy$isNoKidRequirement = (value) =>
  value instanceof NoKidRequirement;

/**
 * Token must have a kid header, but it doesn't need to match a configured key
 */
export class RequireKid extends $CustomType {}
export const KidPolicy$RequireKid$const = new RequireKid();
export const KidPolicy$RequireKid = () => KidPolicy$RequireKid$const;
export const KidPolicy$isRequireKid = (value) => value instanceof RequireKid;

/**
 * Token must have a kid header AND it must match a configured key's kid
 */
export class RequireKidMatch extends $CustomType {}
export const KidPolicy$RequireKidMatch$const = new RequireKidMatch();
export const KidPolicy$RequireKidMatch = () => KidPolicy$RequireKidMatch$const;
export const KidPolicy$isRequireKidMatch = (value) =>
  value instanceof RequireKidMatch;

export class JwtValidationOptions extends $CustomType {
  constructor(issuer, audience, clock_skew, require_exp, max_token_age, jti_validator, kid_policy) {
    super();
    this.issuer = issuer;
    this.audience = audience;
    this.clock_skew = clock_skew;
    this.require_exp = require_exp;
    this.max_token_age = max_token_age;
    this.jti_validator = jti_validator;
    this.kid_policy = kid_policy;
  }
}
export const JwtValidationOptions$JwtValidationOptions = (issuer, audience, clock_skew, require_exp, max_token_age, jti_validator, kid_policy) =>
  new JwtValidationOptions(issuer,
  audience,
  clock_skew,
  require_exp,
  max_token_age,
  jti_validator,
  kid_policy);
export const JwtValidationOptions$isJwtValidationOptions = (value) =>
  value instanceof JwtValidationOptions;
export const JwtValidationOptions$JwtValidationOptions$issuer = (value) =>
  value.issuer;
export const JwtValidationOptions$JwtValidationOptions$0 = (value) =>
  value.issuer;
export const JwtValidationOptions$JwtValidationOptions$audience = (value) =>
  value.audience;
export const JwtValidationOptions$JwtValidationOptions$1 = (value) =>
  value.audience;
export const JwtValidationOptions$JwtValidationOptions$clock_skew = (value) =>
  value.clock_skew;
export const JwtValidationOptions$JwtValidationOptions$2 = (value) =>
  value.clock_skew;
export const JwtValidationOptions$JwtValidationOptions$require_exp = (value) =>
  value.require_exp;
export const JwtValidationOptions$JwtValidationOptions$3 = (value) =>
  value.require_exp;
export const JwtValidationOptions$JwtValidationOptions$max_token_age = (value) =>
  value.max_token_age;
export const JwtValidationOptions$JwtValidationOptions$4 = (value) =>
  value.max_token_age;
export const JwtValidationOptions$JwtValidationOptions$jti_validator = (value) =>
  value.jti_validator;
export const JwtValidationOptions$JwtValidationOptions$5 = (value) =>
  value.jti_validator;
export const JwtValidationOptions$JwtValidationOptions$kid_policy = (value) =>
  value.kid_policy;
export const JwtValidationOptions$JwtValidationOptions$6 = (value) =>
  value.kid_policy;

class Verifier extends $CustomType {
  constructor(alg, keys, options) {
    super();
    this.alg = alg;
    this.keys = keys;
    this.options = options;
  }
}

const reserved_claims = /* @__PURE__ */ toList([
  "iss",
  "sub",
  "aud",
  "exp",
  "nbf",
  "iat",
  "jti",
]);

/**
 * Convert a JOSE error to a MalformedToken error.
 * 
 * @ignore
 */
export function gose_error_to_malformed_token_error(err) {
  return new MalformedToken($gose.error_message(err));
}

/**
 * Create default validation options.
 *
 * Default settings:
 * - No issuer validation
 * - No audience validation
 * - 60 seconds clock skew tolerance
 * - Expiration claim required
 * - No max token age
 * - No JWT ID validator
 * - No kid requirement (prioritizes matching keys but tries all)
 *
 * When an `iat` claim is present, it is always checked to ensure it is not
 * in the future (beyond clock skew), regardless of whether `max_token_age`
 * is configured.
 */
export function default_validation() {
  return new JwtValidationOptions(
    $option.Option$None$const,
    $option.Option$None$const,
    60,
    true,
    $option.Option$None$const,
    $option.Option$None$const,
    KidPolicy$NoKidRequirement$const,
  );
}

/**
 * Set a custom JWT ID (jti) validator.
 *
 * The validator function receives the `jti` claim value and should return
 * `True` if the ID is valid, `False` if it should be rejected.
 *
 * Common use cases:
 * - Check against a revocation list
 * - Verify the ID hasn't been seen before (replay prevention)
 * - Validate format/structure of the ID
 *
 * If the token has no `jti` claim, the validator is not called.
 */
export function with_jti_validator(options, validator) {
  return new JwtValidationOptions(
    options.issuer,
    options.audience,
    options.clock_skew,
    options.require_exp,
    options.max_token_age,
    new $option.Some(validator),
    options.kid_policy,
  );
}

/**
 * Set the maximum token age in seconds.
 *
 * If set, tokens with an `iat` claim older than `now - max_age_seconds` will
 * be rejected with `TokenTooOld`. Requires the `iat` claim to be present.
 * Tokens without `iat` are rejected with `MissingIssuedAt`.
 */
export function with_max_token_age(options, max_age_seconds) {
  return new JwtValidationOptions(
    options.issuer,
    options.audience,
    options.clock_skew,
    options.require_exp,
    new $option.Some(max_age_seconds),
    options.jti_validator,
    options.kid_policy,
  );
}

function build_verifier(alg, keys, options) {
  return $key_helpers.require_non_empty_keys(
    keys,
    () => {
      return $result.try$(
        $list.try_each(
          keys,
          (_capture) => {
            return $key_helpers.validate_key_for_signing_verification(
              alg,
              _capture,
            );
          },
        ),
        (_) => { return new Ok(new Verifier(alg, keys, options)); },
      );
    },
  );
}

/**
 * Create a verifier for JWT signature verification and claim validation.
 *
 * Each verifier is pinned to a single algorithm. This prevents algorithm
 * confusion attacks where an attacker changes the `alg` header to trick
 * the verifier into using the wrong algorithm (see RFC 8725 Section 3.1).
 * For multi-algorithm scenarios (e.g., algorithm migration), create one
 * verifier per algorithm and try each in sequence:
 *
 * ```gleam
 * let assert Ok(rs_verifier) = jwt.verifier(
 *   gose.DigitalSignature(gose.RsaPkcs1(gose.RsaPkcs1Sha256)),
 *   keys: rsa_keys,
 *   options: jwt.default_validation(),
 * )
 * let assert Ok(ec_verifier) = jwt.verifier(
 *   gose.DigitalSignature(gose.Ecdsa(gose.EcdsaP256)),
 *   keys: ec_keys,
 *   options: jwt.default_validation(),
 * )
 *
 * let result = case jwt.verify_and_validate(rs_verifier, token, now) {
 *   Ok(verified) -> Ok(verified)
 *   _ -> jwt.verify_and_validate(ec_verifier, token, now)
 * }
 * ```
 *
 * Accepts one or more keys for key rotation scenarios.
 *
 * Key selection during verification:
 * 1. If token has `kid` header, prioritize keys with matching kid
 * 2. Try keys in order until one succeeds
 * 3. Fail if no key verifies the signature
 *
 * Returns an error if:
 * - The key list is empty
 * - Any algorithm is incompatible with any key type
 * - Any key's `use` field is set but not `Signing`
 * - Any key's `key_ops` field is set but doesn't include `Verify`
 */
export function verifier(alg, keys, options) {
  let _pipe = build_verifier(alg, keys, options);
  return $result.map_error(_pipe, (var0) => { return new JoseError(var0); });
}

/**
 * Create an empty claims set with no registered or custom claims.
 * Use the `with_*` functions to populate claims before signing.
 */
export function claims() {
  return new Claims(
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $dict.new$(),
  );
}

/**
 * Set a single audience (aud) claim.
 */
export function with_audience(claims, aud) {
  return new Claims(
    claims.iss,
    claims.sub,
    new $option.Some(toList([aud])),
    claims.exp,
    claims.nbf,
    claims.iat,
    claims.jti,
    claims.custom,
  );
}

/**
 * Set multiple audiences (aud) claim.
 *
 * Returns an error if the audience list is empty.
 */
export function with_audiences(claims, aud) {
  if (aud instanceof $Empty) {
    return new Error(new InvalidClaim("audience list cannot be empty"));
  } else {
    return new Ok(
      new Claims(
        claims.iss,
        claims.sub,
        new $option.Some(aud),
        claims.exp,
        claims.nbf,
        claims.iat,
        claims.jti,
        claims.custom,
      ),
    );
  }
}

/**
 * Set a custom claim.
 *
 * Returns an error if the key is a reserved claim name. Use the dedicated
 * setters for registered claims (e.g., `with_issuer`, `with_subject`).
 */
export function with_claim(claims, key, value) {
  let $ = $list.contains(reserved_claims, key);
  if ($) {
    return new Error(
      new InvalidClaim(("use dedicated setter for " + key) + " claim"),
    );
  } else {
    return new Ok(
      new Claims(
        claims.iss,
        claims.sub,
        claims.aud,
        claims.exp,
        claims.nbf,
        claims.iat,
        claims.jti,
        $dict.insert(claims.custom, key, value),
      ),
    );
  }
}

/**
 * Set the expiration time (exp) claim.
 */
export function with_expiration(claims, exp) {
  let $ = $timestamp.to_unix_seconds_and_nanoseconds(exp);
  let seconds = $[0];
  return new Claims(
    claims.iss,
    claims.sub,
    claims.aud,
    new $option.Some(seconds),
    claims.nbf,
    claims.iat,
    claims.jti,
    claims.custom,
  );
}

/**
 * Set the issued at time (iat) claim.
 */
export function with_issued_at(claims, iat) {
  let $ = $timestamp.to_unix_seconds_and_nanoseconds(iat);
  let seconds = $[0];
  return new Claims(
    claims.iss,
    claims.sub,
    claims.aud,
    claims.exp,
    claims.nbf,
    new $option.Some(seconds),
    claims.jti,
    claims.custom,
  );
}

/**
 * Set the issuer (iss) claim.
 */
export function with_issuer(claims, iss) {
  return new Claims(
    new $option.Some(iss),
    claims.sub,
    claims.aud,
    claims.exp,
    claims.nbf,
    claims.iat,
    claims.jti,
    claims.custom,
  );
}

/**
 * Set the JWT ID (jti) claim.
 */
export function with_jwt_id(claims, jti) {
  return new Claims(
    claims.iss,
    claims.sub,
    claims.aud,
    claims.exp,
    claims.nbf,
    claims.iat,
    new $option.Some(jti),
    claims.custom,
  );
}

/**
 * Set the not before time (nbf) claim.
 */
export function with_not_before(claims, nbf) {
  let $ = $timestamp.to_unix_seconds_and_nanoseconds(nbf);
  let seconds = $[0];
  return new Claims(
    claims.iss,
    claims.sub,
    claims.aud,
    claims.exp,
    new $option.Some(seconds),
    claims.iat,
    claims.jti,
    claims.custom,
  );
}

/**
 * Set the subject (sub) claim.
 */
export function with_subject(claims, sub) {
  return new Claims(
    claims.iss,
    new $option.Some(sub),
    claims.aud,
    claims.exp,
    claims.nbf,
    claims.iat,
    claims.jti,
    claims.custom,
  );
}

/**
 * Get the algorithm (`alg`) from a JWT.
 */
export function alg(jwt) {
  let alg$1 = jwt.alg;
  return alg$1;
}

/**
 * Get the key ID (kid) from a JWT header.
 *
 * **Security Warning:** The `kid` value comes from the token and is untrusted
 * input. If you use it to look up keys (from a database, filesystem, or key
 * store), you must sanitize it first to prevent injection attacks.
 */
export function kid(jwt) {
  let kid$1 = jwt.kid;
  return $option.to_result(kid$1, undefined);
}

function do_sign(unsigned, key, claims_json, alg, kid, claims) {
  return $result.try$(
    $jws.sign(unsigned, key, claims_json),
    (signed) => {
      let _pipe = $jws.serialize_compact(signed);
      return $result.map(
        _pipe,
        (token) => { return new Jwt(alg, kid, claims, claims_json, token); },
      );
    },
  );
}

function apply_optional_kid(unsigned, kid) {
  if (kid instanceof $option.Some) {
    let k = kid[0];
    return $jws.with_kid(unsigned, k);
  } else {
    return unsigned;
  }
}

function claims_to_json(claims) {
  let registered_fields = $option.values(
    toList([
      $option.map(claims.iss, (v) => { return ["iss", $json.string(v)]; }),
      $option.map(claims.sub, (v) => { return ["sub", $json.string(v)]; }),
      $option.map(
        claims.aud,
        (auds) => {
          if (auds instanceof $Empty) {
            let multiple = auds;
            return ["aud", $json.array(multiple, $json.string)];
          } else {
            let $ = auds.tail;
            if ($ instanceof $Empty) {
              let single = auds.head;
              return ["aud", $json.string(single)];
            } else {
              let multiple = auds;
              return ["aud", $json.array(multiple, $json.string)];
            }
          }
        },
      ),
      $option.map(claims.exp, (v) => { return ["exp", $json.int(v)]; }),
      $option.map(claims.nbf, (v) => { return ["nbf", $json.int(v)]; }),
      $option.map(claims.iat, (v) => { return ["iat", $json.int(v)]; }),
      $option.map(claims.jti, (v) => { return ["jti", $json.string(v)]; }),
    ]),
  );
  let custom_fields = $dict.to_list(claims.custom);
  return $json.object($list.append(registered_fields, custom_fields));
}

/**
 * Sign a JWT with the provided key.
 *
 * Automatically sets `typ: "JWT"` in the header. The token is marked
 * `Verified` because locally-signed tokens are implicitly trusted.
 *
 * ## Example
 *
 * ```gleam
 * let claims = jwt.claims()
 *   |> jwt.with_subject("user123")
 *   |> jwt.with_expiration(exp)
 *
 * let assert Ok(signed) = jwt.sign(gose.Mac(gose.Hmac(gose.HmacSha256)), claims, key)
 * let token = jwt.serialize(signed)
 * ```
 */
export function sign(alg, claims, key) {
  let kid$1 = $option.from_result($gose.kid(key));
  let payload = claims_to_json(claims);
  let _block;
  let _pipe = $json.to_string(payload);
  _block = $bit_array.from_string(_pipe);
  let payload_bits = _block;
  let _block$1;
  let _pipe$1 = $jws.new$(alg);
  let _pipe$2 = $jws.with_typ(_pipe$1, "JWT");
  _block$1 = apply_optional_kid(_pipe$2, kid$1);
  let unsigned = _block$1;
  let _pipe$3 = do_sign(unsigned, key, payload_bits, alg, kid$1, claims);
  return $result.map_error(_pipe$3, (var0) => { return new JoseError(var0); });
}

function validate_jti(claims, options) {
  let $ = options.jti_validator;
  let $1 = claims.jti;
  if ($ instanceof $option.Some) {
    if ($1 instanceof $option.Some) {
      let validator = $[0];
      let jti = $1[0];
      return $bool.guard(
        !validator(jti),
        new Error(new InvalidJti(jti)),
        () => { return new Ok(undefined); },
      );
    } else {
      return new Ok(undefined);
    }
  } else {
    return new Ok(undefined);
  }
}

function validate_token_age(iat, now_seconds, options) {
  let $ = options.max_token_age;
  if ($ instanceof $option.Some) {
    let max_age = $[0];
    let token_age = now_seconds - iat;
    return $bool.guard(
      token_age > max_age,
      new Error(new TokenTooOld($timestamp.from_unix_seconds(iat), max_age)),
      () => { return new Ok(undefined); },
    );
  } else {
    return new Ok(undefined);
  }
}

function validate_iat_not_future(iat, now_seconds, options) {
  return $bool.guard(
    iat > (now_seconds + options.clock_skew),
    new Error(new IssuedInFuture($timestamp.from_unix_seconds(iat))),
    () => { return new Ok(undefined); },
  );
}

function validate_iat(claims, now_seconds, options) {
  let $ = claims.iat;
  let $1 = options.max_token_age;
  if ($ instanceof $option.Some) {
    let iat = $[0];
    return $result.try$(
      validate_iat_not_future(iat, now_seconds, options),
      (_) => { return validate_token_age(iat, now_seconds, options); },
    );
  } else if ($1 instanceof $option.Some) {
    return new Error(JwtError$MissingIssuedAt$const);
  } else {
    return new Ok(undefined);
  }
}

function validate_audience(claims, options) {
  let $ = options.audience;
  let $1 = claims.aud;
  if ($ instanceof $option.Some) {
    if ($1 instanceof $option.Some) {
      let expected = $[0];
      let audiences = $1[0];
      let $2 = $list.contains(audiences, expected);
      if ($2) {
        return new Ok(undefined);
      } else {
        return new Error(
          new AudienceMismatch(expected, new $option.Some(audiences)),
        );
      }
    } else {
      let expected = $[0];
      return new Error(
        new AudienceMismatch(expected, $option.Option$None$const),
      );
    }
  } else {
    return new Ok(undefined);
  }
}

function validate_issuer(claims, options) {
  let $ = options.issuer;
  let $1 = claims.iss;
  if ($ instanceof $option.Some) {
    if ($1 instanceof $option.Some) {
      let expected = $[0];
      let actual = $1[0];
      if (expected === actual) {
        return new Ok(undefined);
      } else {
        let actual = $1;
        let expected = $[0];
        return new Error(new IssuerMismatch(expected, actual));
      }
    } else {
      let actual = $1;
      let expected = $[0];
      return new Error(new IssuerMismatch(expected, actual));
    }
  } else {
    return new Ok(undefined);
  }
}

function validate_nbf(claims, now_seconds, options) {
  let $ = claims.nbf;
  if ($ instanceof $option.Some) {
    let nbf = $[0];
    let adjusted_now = now_seconds + options.clock_skew;
    return $bool.guard(
      adjusted_now < nbf,
      new Error(new TokenNotYetValid($timestamp.from_unix_seconds(nbf))),
      () => { return new Ok(undefined); },
    );
  } else {
    return new Ok(undefined);
  }
}

function validate_exp(claims, now_seconds, options) {
  let $ = claims.exp;
  let $1 = options.require_exp;
  if ($ instanceof $option.Some) {
    let exp = $[0];
    let adjusted_now = now_seconds - options.clock_skew;
    return $bool.guard(
      adjusted_now >= exp,
      new Error(new TokenExpired($timestamp.from_unix_seconds(exp))),
      () => { return new Ok(undefined); },
    );
  } else if ($1) {
    return new Error(JwtError$MissingExpiration$const);
  } else {
    return new Ok(undefined);
  }
}

/**
 * Validate JWT claims against the configured validation options.
 *
 * Checks expiration, not-before, issued-at, issuer, audience,
 * JWT ID, and token age constraints.
 * 
 * @ignore
 */
export function validate_claims(claims, now, options) {
  let $ = $timestamp.to_unix_seconds_and_nanoseconds(now);
  let now_seconds = $[0];
  return $result.try$(
    validate_exp(claims, now_seconds, options),
    (_) => {
      return $result.try$(
        validate_nbf(claims, now_seconds, options),
        (_) => {
          return $result.try$(
            validate_issuer(claims, options),
            (_) => {
              return $result.try$(
                validate_audience(claims, options),
                (_) => {
                  return $result.try$(
                    validate_iat(claims, now_seconds, options),
                    (_) => { return validate_jti(claims, options); },
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Decode a verified JWT's claims using a custom decoder.
 *
 * This allows extracting claims directly into your own types using
 * `gleam/dynamic/decode`. The decoder receives the raw claims JSON.
 *
 * ## Example
 *
 * ```gleam
 * let decoder = {
 *   use sub <- decode.field("sub", decode.string)
 *   use role <- decode.field("role", decode.string)
 *   decode.success(User(sub:, role:))
 * }
 * let assert Ok(user) = jwt.decode(verified_jwt, decoder)
 * ```
 */
export function decode(jwt, decoder) {
  let _pipe = $json.parse_bits(jwt.claims_json, decoder);
  return $result.replace_error(
    _pipe,
    new ClaimDecodingFailed("failed to decode claims"),
  );
}

function extract_optional_string(fields, key) {
  let $ = $dict.get(fields, key);
  if ($ instanceof Ok) {
    let value = $[0];
    let _pipe = $decode.run(value, $decode.string);
    let _pipe$1 = $result.map(
      _pipe,
      (var0) => { return new $option.Some(var0); },
    );
    return $result.replace_error(
      _pipe$1,
      new MalformedToken(key + " claim must be a string"),
    );
  } else {
    return new Ok($option.Option$None$const);
  }
}

function extract_optional_numeric_date(fields, key) {
  let $ = $dict.get(fields, key);
  if ($ instanceof Ok) {
    let value = $[0];
    let numeric_decoder = $decode.one_of(
      $decode.int,
      toList([$decode.map($decode.float, $float.truncate)]),
    );
    let _pipe = $decode.run(value, numeric_decoder);
    let _pipe$1 = $result.map(
      _pipe,
      (var0) => { return new $option.Some(var0); },
    );
    return $result.replace_error(
      _pipe$1,
      new MalformedToken(key + " claim must be a numeric value"),
    );
  } else {
    return new Ok($option.Option$None$const);
  }
}

function extract_optional_audience(fields) {
  let $ = $dict.get(fields, "aud");
  if ($ instanceof Ok) {
    let value = $[0];
    let audience_decoder = $decode.one_of(
      $decode.list($decode.string),
      toList([$decode.map($decode.string, $list.wrap)]),
    );
    let $1 = $decode.run(value, audience_decoder);
    if ($1 instanceof Ok) {
      let $2 = $1[0];
      if ($2 instanceof $Empty) {
        return new Error(
          new MalformedToken("aud claim cannot be an empty array"),
        );
      } else {
        let audiences = $2;
        return new Ok(new $option.Some(audiences));
      }
    } else {
      return new Error(
        new MalformedToken("aud claim must be a string or array of strings"),
      );
    }
  } else {
    return new Ok($option.Option$None$const);
  }
}

function parse_claims_from_fields(all_fields) {
  return $result.try$(
    extract_optional_string(all_fields, "iss"),
    (iss) => {
      return $result.try$(
        extract_optional_string(all_fields, "sub"),
        (sub) => {
          return $result.try$(
            extract_optional_audience(all_fields),
            (aud) => {
              return $result.try$(
                extract_optional_numeric_date(all_fields, "exp"),
                (exp) => {
                  return $result.try$(
                    extract_optional_numeric_date(all_fields, "nbf"),
                    (nbf) => {
                      return $result.try$(
                        extract_optional_numeric_date(all_fields, "iat"),
                        (iat) => {
                          return $result.try$(
                            extract_optional_string(all_fields, "jti"),
                            (jti) => {
                              return new Ok(
                                new Claims(
                                  iss,
                                  sub,
                                  aud,
                                  exp,
                                  nbf,
                                  iat,
                                  jti,
                                  $dict.new$(),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Parse a raw JSON payload into JWT claims.
 * 
 * @ignore
 */
export function parse_claims_bits(payload) {
  let $ = $json.parse_bits(
    payload,
    $decode.dict($decode.string, $decode.dynamic),
  );
  if ($ instanceof Ok) {
    let all_fields = $[0];
    return parse_claims_from_fields(all_fields);
  } else {
    return new Error(new MalformedToken("invalid claims JSON"));
  }
}

function build_verified_jwt(signed_jws, token) {
  let claims_json = $jws.payload(signed_jws);
  return $result.try$(
    parse_claims_bits(claims_json),
    (claims) => {
      let alg$1 = $jws.alg(signed_jws);
      let kid$1 = $option.from_result($jws.kid(signed_jws));
      return new Ok(new Jwt(alg$1, kid$1, claims, claims_json, token));
    },
  );
}

function try_verify_with_keys(signed_jws, expected_alg, keys) {
  return $result.try$(
    (() => {
      let _pipe = $jws.verifier(expected_alg, keys);
      return $result.map_error(_pipe, (var0) => { return new JoseError(var0); });
    })(),
    (verifier) => {
      let $ = $jws.verify(verifier, signed_jws);
      if ($ instanceof Ok) {
        return $;
      } else {
        let $1 = $[0];
        if ($1 instanceof $gose.ParseError) {
          let reason = $1[0];
          return new Error(new MalformedToken(reason));
        } else if ($1 instanceof $gose.CryptoError) {
          return new Error(JwtError$InvalidSignature$const);
        } else if ($1 instanceof $gose.InvalidState) {
          let err = $1;
          return new Error(new JoseError(err));
        } else {
          return new Error(JwtError$InvalidSignature$const);
        }
      }
    },
  );
}

/**
 * Select and order keys based on kid matching policy.
 *
 * Filters and reorders the provided keys according to the token's `kid`
 * header and the configured `KidPolicy`.
 * 
 * @ignore
 */
export function select_keys_by_policy(keys, token_kid, kid_policy) {
  if (token_kid instanceof $option.Some) {
    if (kid_policy instanceof NoKidRequirement) {
      return new Ok($key_helpers.order_keys_by_kid(keys, token_kid));
    } else if (kid_policy instanceof RequireKid) {
      return new Ok($key_helpers.order_keys_by_kid(keys, token_kid));
    } else {
      let target = token_kid[0];
      let matching = $list.filter(
        keys,
        (key) => { return isEqual($gose.kid(key), new Ok(target)); },
      );
      if (matching instanceof $Empty) {
        return new Error(new UnknownKid(target));
      } else {
        return new Ok(matching);
      }
    }
  } else if (kid_policy instanceof NoKidRequirement) {
    return new Ok(keys);
  } else if (kid_policy instanceof RequireKid) {
    return new Error(JwtError$MissingKid$const);
  } else {
    return new Error(JwtError$MissingKid$const);
  }
}

function require_matching_algorithm(expected, actual) {
  let $ = isEqual(expected, actual);
  if ($) {
    return new Ok(undefined);
  } else {
    return new Error(new JwsAlgorithmMismatch(expected, actual));
  }
}

function has_unprotected_alg(signed_jws) {
  return $bool.guard(
    !$jws.has_unprotected_header(signed_jws),
    false,
    () => {
      let alg_decoder = $decode.optional_field(
        "alg",
        $option.Option$None$const,
        $decode.optional($decode.dynamic),
        (alg) => { return $decode.success(alg); },
      );
      let $ = $jws.decode_unprotected_header(signed_jws, alg_decoder);
      if ($ instanceof Ok) {
        let $1 = $[0];
        if ($1 instanceof $option.Some) {
          return true;
        } else {
          return false;
        }
      } else {
        return false;
      }
    },
  );
}

/**
 * Validate that a signed JWS is compatible with JWT requirements.
 * JWTs do not support detached payloads or unencoded payloads (b64=false).
 * 
 * @ignore
 */
function require_jwt_compatible_jws(signed_jws) {
  return $bool.guard(
    $jws.is_detached(signed_jws),
    new Error(new MalformedToken("JWTs do not support detached payloads")),
    () => {
      return $bool.guard(
        $jws.has_unencoded_payload(signed_jws),
        new Error(
          new MalformedToken(
            "JWTs do not support unencoded payloads (b64=false)",
          ),
        ),
        () => {
          return $bool.guard(
            has_unprotected_alg(signed_jws),
            new Error(new InsecureUnprotectedHeader("alg")),
            () => { return new Ok(undefined); },
          );
        },
      );
    },
  );
}

function parse_jws(token) {
  let _pipe = $jws.parse_compact(token);
  return $result.map_error(_pipe, gose_error_to_malformed_token_error);
}

/**
 * Verify a JWT's signature and validate its claims using a Verifier.
 *
 * Checks:
 * 1. Token's `alg` header matches the verifier's expected algorithm
 * 2. Signature is valid for one of the verifier's keys
 * 3. Claims pass validation (exp, nbf, iss, aud per options)
 *
 * When multiple keys are configured:
 * - Keys with matching `kid` are tried first (if token has `kid` header)
 * - `kid_policy` controls kid header enforcement (see `KidPolicy` type)
 * - With `NoKidRequirement`, all keys are tried with matching keys prioritized
 */
export function verify_and_validate(verifier, token, now) {
  let expected_alg = verifier.alg;
  let keys = verifier.keys;
  let options = verifier.options;
  return $result.try$(
    parse_jws(token),
    (signed_jws) => {
      return $result.try$(
        require_jwt_compatible_jws(signed_jws),
        (_) => {
          return $result.try$(
            require_matching_algorithm(expected_alg, $jws.alg(signed_jws)),
            (_) => {
              let token_kid = $option.from_result($jws.kid(signed_jws));
              return $result.try$(
                select_keys_by_policy(keys, token_kid, options.kid_policy),
                (verification_keys) => {
                  return $result.try$(
                    try_verify_with_keys(
                      signed_jws,
                      expected_alg,
                      verification_keys,
                    ),
                    (_) => {
                      return $result.try$(
                        build_verified_jwt(signed_jws, token),
                        (jwt) => {
                          return $result.try$(
                            validate_claims(jwt.claims, now, options),
                            (_) => { return new Ok(jwt); },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Verify a JWT's signature only, skipping all claim validation.
 *
 * **Warning:** This skips expiration, not-before, issuer, and audience checks.
 * Use only when you have a legitimate reason to bypass validation, such as
 * inspecting claims before deciding on validation policy.
 *
 * Still enforces algorithm pinning and `kid_policy` for security.
 * When multiple keys are configured, keys with matching `kid` are tried first.
 */
export function verify_and_dangerously_skip_validation(verifier, token) {
  let expected_alg = verifier.alg;
  let keys = verifier.keys;
  let options = verifier.options;
  return $result.try$(
    parse_jws(token),
    (signed_jws) => {
      return $result.try$(
        require_jwt_compatible_jws(signed_jws),
        (_) => {
          return $result.try$(
            require_matching_algorithm(expected_alg, $jws.alg(signed_jws)),
            (_) => {
              let token_kid = $option.from_result($jws.kid(signed_jws));
              return $result.try$(
                select_keys_by_policy(keys, token_kid, options.kid_policy),
                (verification_keys) => {
                  return $result.try$(
                    try_verify_with_keys(
                      signed_jws,
                      expected_alg,
                      verification_keys,
                    ),
                    (_) => { return build_verified_jwt(signed_jws, token); },
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Serialize a verified JWT to compact format.
 */
export function serialize(jwt) {
  return jwt.token;
}

/**
 * Serialize claims to a JSON string.
 *
 * This is useful for encrypted JWTs or other scenarios where you need
 * the raw JSON representation of claims including custom claims.
 * 
 * @ignore
 */
export function claims_to_json_string(claims) {
  let _pipe = claims_to_json(claims);
  return $json.to_string(_pipe);
}

/**
 * Decode an unverified JWT's claims using a custom decoder.
 *
 * **Warning:** These claims have not been verified. Do not trust them
 * until the JWT has been verified with `verify_and_validate`.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(parsed) = jwt.parse(token)
 * let decoder = {
 *   use iss <- decode.field("iss", decode.string)
 *   decode.success(iss)
 * }
 * let assert Ok(issuer) = jwt.dangerously_decode_unverified(parsed, decoder)
 * // issuer is untrusted - only use for routing/lookup, not authorization
 * ```
 */
export function dangerously_decode_unverified(jwt, decoder) {
  let _pipe = $json.parse_bits(jwt.claims_json, decoder);
  return $result.replace_error(
    _pipe,
    new ClaimDecodingFailed("failed to decode claims"),
  );
}

/**
 * Parse a JWT from compact format.
 *
 * Returns an unverified JWT that needs to be verified with
 * `verify_and_validate` or `verify_and_dangerously_skip_validation`.
 */
export function parse(token) {
  return $result.try$(
    parse_jws(token),
    (signed) => {
      return $result.try$(
        require_jwt_compatible_jws(signed),
        (_) => {
          let claims_json = $jws.payload(signed);
          return $result.try$(
            parse_claims_bits(claims_json),
            (claims) => {
              let alg$1 = $jws.alg(signed);
              let kid$1 = $option.from_result($jws.kid(signed));
              return new Ok(new Jwt(alg$1, kid$1, claims, claims_json, token));
            },
          );
        },
      );
    },
  );
}
