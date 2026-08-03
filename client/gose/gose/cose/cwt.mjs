import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $timestamp from "../../../gleam_time/gleam/time/timestamp.mjs";
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  List$Empty$const as $List$Empty$const,
  CustomType as $CustomType,
} from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $cbor from "../../gose/cbor.mjs";
import * as $sign1 from "../../gose/cose/sign1.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";

/**
 * An error from the underlying COSE layer (signing, verification, decryption, key validation).
 */
export class CoseError extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const CwtError$CoseError = ($0) => new CoseError($0);
export const CwtError$isCoseError = (value) => value instanceof CoseError;
export const CwtError$CoseError$0 = (value) => value[0];

/**
 * The COSE_Sign1 signature did not verify against any of the provided keys.
 */
export class InvalidSignature extends $CustomType {}
export const CwtError$InvalidSignature$const = new InvalidSignature();
export const CwtError$InvalidSignature = () => CwtError$InvalidSignature$const;
export const CwtError$isInvalidSignature = (value) =>
  value instanceof InvalidSignature;

/**
 * The token could not be parsed (invalid CBOR, unexpected claim types, etc.).
 */
export class MalformedToken extends $CustomType {
  constructor(reason) {
    super();
    this.reason = reason;
  }
}
export const CwtError$MalformedToken = (reason) => new MalformedToken(reason);
export const CwtError$isMalformedToken = (value) =>
  value instanceof MalformedToken;
export const CwtError$MalformedToken$reason = (value) => value.reason;
export const CwtError$MalformedToken$0 = (value) => value.reason;

/**
 * The `exp` claim is in the past.
 */
export class TokenExpired extends $CustomType {
  constructor(expired_at) {
    super();
    this.expired_at = expired_at;
  }
}
export const CwtError$TokenExpired = (expired_at) =>
  new TokenExpired(expired_at);
export const CwtError$isTokenExpired = (value) => value instanceof TokenExpired;
export const CwtError$TokenExpired$expired_at = (value) => value.expired_at;
export const CwtError$TokenExpired$0 = (value) => value.expired_at;

/**
 * The `nbf` claim is in the future.
 */
export class TokenNotYetValid extends $CustomType {
  constructor(valid_from) {
    super();
    this.valid_from = valid_from;
  }
}
export const CwtError$TokenNotYetValid = (valid_from) =>
  new TokenNotYetValid(valid_from);
export const CwtError$isTokenNotYetValid = (value) =>
  value instanceof TokenNotYetValid;
export const CwtError$TokenNotYetValid$valid_from = (value) => value.valid_from;
export const CwtError$TokenNotYetValid$0 = (value) => value.valid_from;

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
export const CwtError$IssuerMismatch = (expected, actual) =>
  new IssuerMismatch(expected, actual);
export const CwtError$isIssuerMismatch = (value) =>
  value instanceof IssuerMismatch;
export const CwtError$IssuerMismatch$expected = (value) => value.expected;
export const CwtError$IssuerMismatch$0 = (value) => value.expected;
export const CwtError$IssuerMismatch$actual = (value) => value.actual;
export const CwtError$IssuerMismatch$1 = (value) => value.actual;

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
export const CwtError$AudienceMismatch = (expected, actual) =>
  new AudienceMismatch(expected, actual);
export const CwtError$isAudienceMismatch = (value) =>
  value instanceof AudienceMismatch;
export const CwtError$AudienceMismatch$expected = (value) => value.expected;
export const CwtError$AudienceMismatch$0 = (value) => value.expected;
export const CwtError$AudienceMismatch$actual = (value) => value.actual;
export const CwtError$AudienceMismatch$1 = (value) => value.actual;

/**
 * The `exp` claim is required by the verifier but absent.
 */
export class MissingExpiration extends $CustomType {}
export const CwtError$MissingExpiration$const = new MissingExpiration();
export const CwtError$MissingExpiration = () =>
  CwtError$MissingExpiration$const;
export const CwtError$isMissingExpiration = (value) =>
  value instanceof MissingExpiration;

/**
 * COSE decryption failed (wrong key, corrupted ciphertext, etc.).
 */
export class DecryptionFailed extends $CustomType {
  constructor(reason) {
    super();
    this.reason = reason;
  }
}
export const CwtError$DecryptionFailed = (reason) =>
  new DecryptionFailed(reason);
export const CwtError$isDecryptionFailed = (value) =>
  value instanceof DecryptionFailed;
export const CwtError$DecryptionFailed$reason = (value) => value.reason;
export const CwtError$DecryptionFailed$0 = (value) => value.reason;

/**
 * A claim value is invalid (empty audience list, etc.).
 */
export class InvalidClaim extends $CustomType {
  constructor(reason) {
    super();
    this.reason = reason;
  }
}
export const CwtError$InvalidClaim = (reason) => new InvalidClaim(reason);
export const CwtError$isInvalidClaim = (value) => value instanceof InvalidClaim;
export const CwtError$InvalidClaim$reason = (value) => value.reason;
export const CwtError$InvalidClaim$0 = (value) => value.reason;

class CwtClaims extends $CustomType {
  constructor(iss, sub, aud, exp, nbf, iat, cti, custom) {
    super();
    this.iss = iss;
    this.sub = sub;
    this.aud = aud;
    this.exp = exp;
    this.nbf = nbf;
    this.iat = iat;
    this.cti = cti;
    this.custom = custom;
  }
}

class Cwt extends $CustomType {
  constructor(claims) {
    super();
    this.claims = claims;
  }
}

class Verifier extends $CustomType {
  constructor(alg, keys, expected_issuer, expected_audience, clock_skew, require_exp) {
    super();
    this.alg = alg;
    this.keys = keys;
    this.expected_issuer = expected_issuer;
    this.expected_audience = expected_audience;
    this.clock_skew = clock_skew;
    this.require_exp = require_exp;
  }
}

/**
 * Create an empty set of CWT claims.
 */
export function new$() {
  return new CwtClaims(
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $List$Empty$const,
  );
}

/**
 * Set the issuer (`iss`, label 1) claim.
 */
export function with_issuer(claims, issuer) {
  return new CwtClaims(
    new $option.Some(issuer),
    claims.sub,
    claims.aud,
    claims.exp,
    claims.nbf,
    claims.iat,
    claims.cti,
    claims.custom,
  );
}

/**
 * Set the subject (`sub`, label 2) claim.
 */
export function with_subject(claims, subject) {
  return new CwtClaims(
    claims.iss,
    new $option.Some(subject),
    claims.aud,
    claims.exp,
    claims.nbf,
    claims.iat,
    claims.cti,
    claims.custom,
  );
}

/**
 * Set a single audience (`aud`, label 3) claim.
 */
export function with_audience(claims, audience) {
  return new CwtClaims(
    claims.iss,
    claims.sub,
    new $option.Some(toList([audience])),
    claims.exp,
    claims.nbf,
    claims.iat,
    claims.cti,
    claims.custom,
  );
}

/**
 * Set multiple audiences (`aud`, label 3) as an array.
 */
export function with_audiences(claims, audiences) {
  if (audiences instanceof $Empty) {
    return new Error(new InvalidClaim("audience list cannot be empty"));
  } else {
    return new Ok(
      new CwtClaims(
        claims.iss,
        claims.sub,
        new $option.Some(audiences),
        claims.exp,
        claims.nbf,
        claims.iat,
        claims.cti,
        claims.custom,
      ),
    );
  }
}

/**
 * Set the expiration time (`exp`, label 4) claim.
 */
export function with_expiration(claims, exp) {
  let $ = $timestamp.to_unix_seconds_and_nanoseconds(exp);
  let seconds = $[0];
  return new CwtClaims(
    claims.iss,
    claims.sub,
    claims.aud,
    new $option.Some(seconds),
    claims.nbf,
    claims.iat,
    claims.cti,
    claims.custom,
  );
}

/**
 * Set the not-before time (`nbf`, label 5) claim.
 */
export function with_not_before(claims, nbf) {
  let $ = $timestamp.to_unix_seconds_and_nanoseconds(nbf);
  let seconds = $[0];
  return new CwtClaims(
    claims.iss,
    claims.sub,
    claims.aud,
    claims.exp,
    new $option.Some(seconds),
    claims.iat,
    claims.cti,
    claims.custom,
  );
}

/**
 * Set the issued-at time (`iat`, label 6) claim.
 */
export function with_issued_at(claims, iat) {
  let $ = $timestamp.to_unix_seconds_and_nanoseconds(iat);
  let seconds = $[0];
  return new CwtClaims(
    claims.iss,
    claims.sub,
    claims.aud,
    claims.exp,
    claims.nbf,
    new $option.Some(seconds),
    claims.cti,
    claims.custom,
  );
}

/**
 * Set the CWT ID (`cti`, label 7) claim.
 */
export function with_cti(claims, cti) {
  return new CwtClaims(
    claims.iss,
    claims.sub,
    claims.aud,
    claims.exp,
    claims.nbf,
    claims.iat,
    new $option.Some(cti),
    claims.custom,
  );
}

/**
 * Add a custom (non-registered) claim keyed by an arbitrary CBOR value.
 *
 * Returns an error if the key collides with a registered CWT label (1-7).
 * If the key already exists in custom claims, the value is replaced.
 */
export function with_custom_claim(claims, key, value) {
  if (key instanceof $cbor.Int) {
    let n = key[0];
    if ((n >= 1) && (n <= 7)) {
      return new Error(
        new MalformedToken(
          "custom claim key collides with registered CWT label " + $int.to_string(
            n,
          ),
        ),
      );
    } else {
      return new Ok(
        new CwtClaims(
          claims.iss,
          claims.sub,
          claims.aud,
          claims.exp,
          claims.nbf,
          claims.iat,
          claims.cti,
          $list.key_set(claims.custom, key, value),
        ),
      );
    }
  } else {
    return new Ok(
      new CwtClaims(
        claims.iss,
        claims.sub,
        claims.aud,
        claims.exp,
        claims.nbf,
        claims.iat,
        claims.cti,
        $list.key_set(claims.custom, key, value),
      ),
    );
  }
}

/**
 * Read the issuer claim.
 */
export function issuer(claims) {
  return $option.to_result(claims.iss, undefined);
}

/**
 * Read the subject claim.
 */
export function subject(claims) {
  return $option.to_result(claims.sub, undefined);
}

/**
 * Read the audience claim as a list of strings.
 */
export function audience(claims) {
  return $option.to_result(claims.aud, undefined);
}

/**
 * Read the expiration time as a timestamp.
 */
export function expiration(claims) {
  let _pipe = $option.to_result(claims.exp, undefined);
  return $result.map(_pipe, $timestamp.from_unix_seconds);
}

/**
 * Read the not-before time as a timestamp.
 */
export function not_before(claims) {
  let _pipe = $option.to_result(claims.nbf, undefined);
  return $result.map(_pipe, $timestamp.from_unix_seconds);
}

/**
 * Read the issued-at time as a timestamp.
 */
export function issued_at(claims) {
  let _pipe = $option.to_result(claims.iat, undefined);
  return $result.map(_pipe, $timestamp.from_unix_seconds);
}

/**
 * Read the CWT ID.
 */
export function cti(claims) {
  return $option.to_result(claims.cti, undefined);
}

/**
 * Look up a custom claim by its CBOR key.
 */
export function custom_claim(claims, key) {
  return $list.key_find(claims.custom, key);
}

function encode_audience(audiences) {
  if (audiences instanceof $Empty) {
    let multiple = audiences;
    return [
      new $cbor.Int(3),
      new $cbor.Array(
        $list.map(multiple, (var0) => { return new $cbor.Text(var0); }),
      ),
    ];
  } else {
    let $ = audiences.tail;
    if ($ instanceof $Empty) {
      let single = audiences.head;
      return [new $cbor.Int(3), new $cbor.Text(single)];
    } else {
      let multiple = audiences;
      return [
        new $cbor.Int(3),
        new $cbor.Array(
          $list.map(multiple, (var0) => { return new $cbor.Text(var0); }),
        ),
      ];
    }
  }
}

function encode_registered_claims(claims) {
  return $option.values(
    toList([
      $option.map(
        claims.iss,
        (v) => { return [new $cbor.Int(1), new $cbor.Text(v)]; },
      ),
      $option.map(
        claims.sub,
        (v) => { return [new $cbor.Int(2), new $cbor.Text(v)]; },
      ),
      $option.map(claims.aud, encode_audience),
      $option.map(
        claims.exp,
        (v) => { return [new $cbor.Int(4), new $cbor.Int(v)]; },
      ),
      $option.map(
        claims.nbf,
        (v) => { return [new $cbor.Int(5), new $cbor.Int(v)]; },
      ),
      $option.map(
        claims.iat,
        (v) => { return [new $cbor.Int(6), new $cbor.Int(v)]; },
      ),
      $option.map(
        claims.cti,
        (v) => { return [new $cbor.Int(7), new $cbor.Bytes(v)]; },
      ),
    ]),
  );
}

function encode_claims(claims) {
  let pairs = encode_registered_claims(claims);
  let all_pairs = $list.append(pairs, claims.custom);
  return $cbor.encode(new $cbor.Map(all_pairs));
}

/**
 * Sign a set of claims as a COSE_Sign1-wrapped CWT, returning the serialized CBOR bytes.
 */
export function sign(claims, alg, key) {
  let payload = encode_claims(claims);
  let unsigned = $sign1.new$(alg);
  let _pipe = $sign1.sign(unsigned, key, payload);
  let _pipe$1 = $result.map(_pipe, $sign1.serialize);
  return $result.map_error(_pipe$1, (var0) => { return new CoseError(var0); });
}

function build_verifier(alg, keys) {
  return $key_helpers.require_non_empty_keys(
    keys,
    () => {
      return $result.try$(
        $list.try_each(
          keys,
          (_capture) => {
            return $key_helpers.validate_key_for_signing_verification(
              new $gose.DigitalSignature(alg),
              _capture,
            );
          },
        ),
        (_) => {
          return new Ok(
            new Verifier(
              alg,
              keys,
              $option.Option$None$const,
              $option.Option$None$const,
              60,
              true,
            ),
          );
        },
      );
    },
  );
}

/**
 * Build a CWT verifier pinned to a single signature algorithm and one or more keys.
 */
export function verifier(alg, keys) {
  let _pipe = build_verifier(alg, keys);
  return $result.map_error(_pipe, (var0) => { return new CoseError(var0); });
}

/**
 * Require the token's `iss` claim to match the given issuer.
 */
export function with_issuer_validation(verifier, issuer) {
  return new Verifier(
    verifier.alg,
    verifier.keys,
    new $option.Some(issuer),
    verifier.expected_audience,
    verifier.clock_skew,
    verifier.require_exp,
  );
}

/**
 * Require the token's `aud` claim to include the given audience.
 */
export function with_audience_validation(verifier, audience) {
  return new Verifier(
    verifier.alg,
    verifier.keys,
    verifier.expected_issuer,
    new $option.Some(audience),
    verifier.clock_skew,
    verifier.require_exp,
  );
}

/**
 * Set the allowed clock skew in seconds (default: 60).
 * Tokens are accepted up to `seconds` past `exp` or before `nbf`.
 */
export function with_clock_skew(verifier, seconds) {
  return new Verifier(
    verifier.alg,
    verifier.keys,
    verifier.expected_issuer,
    verifier.expected_audience,
    seconds,
    verifier.require_exp,
  );
}

/**
 * Control whether the `exp` claim is required (default: `True`).
 */
export function with_require_expiration(verifier, required) {
  return new Verifier(
    verifier.alg,
    verifier.keys,
    verifier.expected_issuer,
    verifier.expected_audience,
    verifier.clock_skew,
    required,
  );
}

function validate_audience_claim(claims, verifier) {
  let $ = verifier.expected_audience;
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

function validate_issuer(claims, verifier) {
  let $ = verifier.expected_issuer;
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

function validate_nbf(claims, now_seconds, verifier) {
  let $ = claims.nbf;
  if ($ instanceof $option.Some) {
    let nbf = $[0];
    let adjusted_now = now_seconds + verifier.clock_skew;
    return $bool.guard(
      adjusted_now < nbf,
      new Error(new TokenNotYetValid($timestamp.from_unix_seconds(nbf))),
      () => { return new Ok(undefined); },
    );
  } else {
    return new Ok(undefined);
  }
}

function validate_exp(claims, now_seconds, verifier) {
  let $ = claims.exp;
  let $1 = verifier.require_exp;
  if ($ instanceof $option.Some) {
    let exp = $[0];
    let adjusted_now = now_seconds - verifier.clock_skew;
    return $bool.guard(
      adjusted_now >= exp,
      new Error(new TokenExpired($timestamp.from_unix_seconds(exp))),
      () => { return new Ok(undefined); },
    );
  } else if ($1) {
    return new Error(CwtError$MissingExpiration$const);
  } else {
    return new Ok(undefined);
  }
}

function validate_claims(claims, now, verifier) {
  let $ = $timestamp.to_unix_seconds_and_nanoseconds(now);
  let now_seconds = $[0];
  return $result.try$(
    validate_exp(claims, now_seconds, verifier),
    (_) => {
      return $result.try$(
        validate_nbf(claims, now_seconds, verifier),
        (_) => {
          return $result.try$(
            validate_issuer(claims, verifier),
            (_) => { return validate_audience_claim(claims, verifier); },
          );
        },
      );
    },
  );
}

function extract_custom_claims(pairs) {
  return $list.filter(
    pairs,
    (pair) => {
      let $ = pair[0];
      if ($ instanceof $cbor.Int) {
        let $1 = $[0];
        if ($1 === 1) {
          return false;
        } else if ($1 === 2) {
          return false;
        } else if ($1 === 3) {
          return false;
        } else if ($1 === 4) {
          return false;
        } else if ($1 === 5) {
          return false;
        } else if ($1 === 6) {
          return false;
        } else if ($1 === 7) {
          return false;
        } else {
          return true;
        }
      } else {
        return true;
      }
    },
  );
}

function decode_optional_bytes(pairs, label, name) {
  let $ = $list.key_find(pairs, new $cbor.Int(label));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Bytes) {
      let v = $1[0];
      return new Ok(new $option.Some(v));
    } else {
      return new Error(
        new MalformedToken(name + " claim must be a byte string"),
      );
    }
  } else {
    return new Ok($option.Option$None$const);
  }
}

function decode_optional_int(pairs, label, name) {
  let $ = $list.key_find(pairs, new $cbor.Int(label));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Int) {
      let v = $1[0];
      return new Ok(new $option.Some(v));
    } else {
      return new Error(new MalformedToken(name + " claim must be an integer"));
    }
  } else {
    return new Ok($option.Option$None$const);
  }
}

function decode_audience_array(items) {
  let _pipe = $list.try_map(
    items,
    (item) => {
      if (item instanceof $cbor.Text) {
        let s = item[0];
        return new Ok(s);
      } else {
        return new Error(
          new MalformedToken("aud array must contain only text strings"),
        );
      }
    },
  );
  return $result.map(_pipe, (var0) => { return new $option.Some(var0); });
}

function decode_optional_audience(pairs) {
  let $ = $list.key_find(pairs, new $cbor.Int(3));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Text) {
      let v = $1[0];
      return new Ok(new $option.Some(toList([v])));
    } else if ($1 instanceof $cbor.Array) {
      let items = $1[0];
      return decode_audience_array(items);
    } else {
      return new Error(
        new MalformedToken(
          "aud claim must be a text string or array of text strings",
        ),
      );
    }
  } else {
    return new Ok($option.Option$None$const);
  }
}

function decode_optional_text(pairs, label, name) {
  let $ = $list.key_find(pairs, new $cbor.Int(label));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Text) {
      let v = $1[0];
      return new Ok(new $option.Some(v));
    } else {
      return new Error(
        new MalformedToken(name + " claim must be a text string"),
      );
    }
  } else {
    return new Ok($option.Option$None$const);
  }
}

function decode_claims_from_map(pairs) {
  return $result.try$(
    decode_optional_text(pairs, 1, "iss"),
    (iss) => {
      return $result.try$(
        decode_optional_text(pairs, 2, "sub"),
        (sub) => {
          return $result.try$(
            decode_optional_audience(pairs),
            (aud) => {
              return $result.try$(
                decode_optional_int(pairs, 4, "exp"),
                (exp) => {
                  return $result.try$(
                    decode_optional_int(pairs, 5, "nbf"),
                    (nbf) => {
                      return $result.try$(
                        decode_optional_int(pairs, 6, "iat"),
                        (iat) => {
                          return $result.try$(
                            decode_optional_bytes(pairs, 7, "cti"),
                            (cti) => {
                              let custom = extract_custom_claims(pairs);
                              return new Ok(
                                new CwtClaims(
                                  iss,
                                  sub,
                                  aud,
                                  exp,
                                  nbf,
                                  iat,
                                  cti,
                                  custom,
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

function decode_claims(payload) {
  let $ = $cbor.decode(payload);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Map) {
      let pairs = $1[0];
      return decode_claims_from_map(pairs);
    } else {
      return new Error(new MalformedToken("CWT claims must be a CBOR map"));
    }
  } else {
    let err = $[0];
    return new Error(new MalformedToken($gose.error_message(err)));
  }
}

function extract_payload(parsed) {
  let _pipe = $sign1.payload(parsed);
  return $result.replace_error(_pipe, new MalformedToken("missing payload"));
}

function verify_signature(alg, keys, parsed) {
  return $result.try$(
    (() => {
      let _pipe = $sign1.verifier(alg, keys);
      return $result.map_error(_pipe, (var0) => { return new CoseError(var0); });
    })(),
    (sign1_verifier) => {
      let $ = $sign1.verify(sign1_verifier, parsed);
      if ($ instanceof Ok) {
        return $;
      } else {
        let $1 = $[0];
        if ($1 instanceof $gose.CryptoError) {
          return new Error(CwtError$InvalidSignature$const);
        } else if ($1 instanceof $gose.VerificationFailed) {
          return new Error(CwtError$InvalidSignature$const);
        } else {
          let err = $1;
          return new Error(new CoseError(err));
        }
      }
    },
  );
}

function parse_sign1(token) {
  let _pipe = $sign1.parse(token);
  return $result.map_error(
    _pipe,
    (err) => { return new MalformedToken($gose.error_message(err)); },
  );
}

/**
 * Parse, verify the signature, and validate claims in one step.
 */
export function verify_and_validate(verifier, token, now) {
  let alg = verifier.alg;
  let keys = verifier.keys;
  return $result.try$(
    parse_sign1(token),
    (parsed) => {
      return $result.try$(
        verify_signature(alg, keys, parsed),
        (_) => {
          return $result.try$(
            extract_payload(parsed),
            (payload) => {
              return $result.try$(
                decode_claims(payload),
                (claims) => {
                  return $result.try$(
                    validate_claims(claims, now, verifier),
                    (_) => { return new Ok(new Cwt(claims)); },
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
 * Extract the validated claims from a verified CWT.
 */
export function verified_claims(cwt) {
  let claims = cwt.claims;
  return claims;
}
