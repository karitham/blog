import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $pair from "../../../gleam_stdlib/gleam/pair.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $set from "../../../gleam_stdlib/gleam/set.mjs";
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  List$Empty$const as $List$Empty$const,
  toBitArray,
} from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $cbor from "../../gose/cbor.mjs";
import * as $cose from "../../gose/cose.mjs";
import * as $signing from "../../gose/internal/signing.mjs";

const standard_labels = /* @__PURE__ */ toList([1, 2, 3, 4, 5, 6, 7]);

export function serialize_protected(headers) {
  if (headers instanceof $Empty) {
    return toBitArray([]);
  } else {
    return $cbor.encode(new $cbor.Map($cose.headers_to_cbor(headers)));
  }
}

export function decode_protected(data) {
  let $ = $bit_array.byte_size(data);
  if ($ === 0) {
    return new Ok($List$Empty$const);
  } else {
    return $result.try$(
      $cbor.decode(data),
      (value) => {
        if (value instanceof $cbor.Map) {
          let $1 = value[0];
          if ($1 instanceof $Empty) {
            return new Error(
              new $gose.ParseError(
                "empty protected header must be encoded as the empty bstr",
              ),
            );
          } else {
            let pairs = $1;
            return $cose.headers_from_cbor(pairs);
          }
        } else {
          return new Error(
            new $gose.ParseError("protected header is not a CBOR map"),
          );
        }
      },
    );
  }
}

export function decode_unprotected(pairs) {
  return $cose.headers_from_cbor(pairs);
}

export function validate_no_header_overlap(protected$, unprotected) {
  let protected_cbor = $cose.headers_to_cbor(protected$);
  let unprotected_cbor = $cose.headers_to_cbor(unprotected);
  let protected_keys = $list.map(protected_cbor, $pair.first);
  let has_overlap = $list.any(
    unprotected_cbor,
    (entry) => { return $list.contains(protected_keys, entry[0]); },
  );
  return $bool.guard(
    has_overlap,
    new Error(
      new $gose.ParseError(
        "duplicate label in protected and unprotected headers",
      ),
    ),
    () => { return new Ok(undefined); },
  );
}

export function validate_iv_partial_iv_exclusion(protected$, unprotected) {
  let all_headers = $list.append(protected$, unprotected);
  let has_iv = $list.any(
    all_headers,
    (h) => {
      if (h instanceof $cose.Iv) {
        return true;
      } else {
        return false;
      }
    },
  );
  let has_partial_iv = $list.any(
    all_headers,
    (h) => {
      if (h instanceof $cose.PartialIv) {
        return true;
      } else {
        return false;
      }
    },
  );
  return $bool.guard(
    has_iv && has_partial_iv,
    new Error(
      new $gose.ParseError("IV and Partial IV must not both be present"),
    ),
    () => { return new Ok(undefined); },
  );
}

function validate_crit_labels(labels, protected$) {
  let crit_set = $set.from_list(labels);
  return $bool.guard(
    $list.is_empty(labels),
    new Error(new $gose.ParseError("crit array must not be empty")),
    () => {
      return $bool.guard(
        $list.length(labels) !== $set.size(crit_set),
        new Error(new $gose.ParseError("crit array contains duplicate values")),
        () => {
          let _block;
          let _pipe = $cose.headers_to_cbor(protected$);
          _block = $list.map(_pipe, $pair.first);
          let protected_keys = _block;
          let standard_set = $set.from_list(standard_labels);
          return $list.try_each(
            labels,
            (label) => {
              let is_present = $list.contains(
                protected_keys,
                new $cbor.Int(label),
              );
              return $bool.guard(
                !is_present,
                new Error(
                  new $gose.ParseError(
                    "crit references label not in protected headers: " + $int.to_string(
                      label,
                    ),
                  ),
                ),
                () => {
                  let $ = $set.contains(standard_set, label);
                  if ($) {
                    return new Ok(undefined);
                  } else {
                    return new Error(
                      new $gose.ParseError(
                        "unsupported critical header: " + $int.to_string(label),
                      ),
                    );
                  }
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
 * Validate the `crit` header.
 *
 * Only standard COSE header labels (1-7) are accepted in the `crit`
 * array. Application-specific critical headers are not currently
 * supported and will be rejected with a parse error. Standard labels
 * in `crit` are accepted but have no additional effect since they are
 * always understood.
 */
export function validate_crit(protected$, unprotected) {
  let has_crit_in_unprotected = $list.any(
    unprotected,
    (h) => {
      if (h instanceof $cose.Crit) {
        return true;
      } else {
        return false;
      }
    },
  );
  return $bool.guard(
    has_crit_in_unprotected,
    new Error(
      new $gose.ParseError("crit header must be in the protected bucket"),
    ),
    () => {
      let $ = $cose.critical(protected$);
      if ($ instanceof Ok) {
        let labels = $[0];
        return validate_crit_labels(labels, protected$);
      } else {
        return new Ok(undefined);
      }
    },
  );
}

export function extract_signing_alg_from_headers(headers) {
  return $result.try$(
    $cose.algorithm(headers),
    (id) => { return $cose.signing_alg_from_int(id); },
  );
}

export function extract_signature_alg_from_headers(headers) {
  return $result.try$(
    $cose.algorithm(headers),
    (id) => { return $cose.signature_alg_from_int(id); },
  );
}

function with_decoded_protected(protected_serialized, extract) {
  let $ = $bit_array.byte_size(protected_serialized);
  if ($ === 0) {
    return new Error(
      new $gose.ParseError("empty protected header, no alg found"),
    );
  } else {
    return $result.try$(
      decode_protected(protected_serialized),
      (headers) => { return extract(headers); },
    );
  }
}

export function extract_signature_alg_from_serialized(protected_serialized) {
  return with_decoded_protected(
    protected_serialized,
    extract_signature_alg_from_headers,
  );
}

export function extract_content_alg_from_headers(headers) {
  return $result.try$(
    $cose.algorithm(headers),
    (id) => { return $cose.content_alg_from_int(id); },
  );
}

export function extract_signing_alg_from_serialized(protected_serialized) {
  return with_decoded_protected(
    protected_serialized,
    extract_signing_alg_from_headers,
  );
}

export function extract_content_alg_from_serialized(protected_serialized) {
  return with_decoded_protected(
    protected_serialized,
    extract_content_alg_from_headers,
  );
}

export function extract_key_encryption_alg_from_headers(headers) {
  return $result.try$(
    $cose.algorithm(headers),
    (id) => { return $cose.key_encryption_alg_from_int(id); },
  );
}

export function extract_key_encryption_alg_from_serialized(protected_serialized) {
  return with_decoded_protected(
    protected_serialized,
    extract_key_encryption_alg_from_headers,
  );
}

export function decode_payload(value) {
  if (value instanceof $cbor.Bytes) {
    let b = value[0];
    return new Ok(new $option.Some(b));
  } else if (value instanceof $cbor.Null) {
    return new Ok($option.Option$None$const);
  } else {
    return new Error(
      new $gose.ParseError("invalid COSE payload: expected bstr or null"),
    );
  }
}

export function try_verify_keys(
  loop$alg,
  loop$keys,
  loop$message,
  loop$signature
) {
  while (true) {
    let alg = loop$alg;
    let keys = loop$keys;
    let message = loop$message;
    let signature = loop$signature;
    if (keys instanceof $Empty) {
      return new Error($gose.GoseError$VerificationFailed$const);
    } else {
      let key = keys.head;
      let rest = keys.tail;
      let $ = $signing.verify_signature(alg, key, message, signature);
      if ($ instanceof Ok) {
        return $;
      } else {
        let $1 = $[0];
        if ($1 instanceof $gose.VerificationFailed) {
          loop$alg = alg;
          loop$keys = rest;
          loop$message = message;
          loop$signature = signature;
        } else {
          return $;
        }
      }
    }
  }
}

export function parse_cose_array_value(
  loop$value,
  loop$expected_tag,
  loop$expected_length
) {
  while (true) {
    let value = loop$value;
    let expected_tag = loop$expected_tag;
    let expected_length = loop$expected_length;
    if (value instanceof $cbor.Array) {
      let items = value[0];
      let $ = $list.length(items) === expected_length;
      if ($) {
        return new Ok(items);
      } else {
        return new Error(new $gose.ParseError("invalid COSE structure"));
      }
    } else if (value instanceof $cbor.Tag) {
      let tag = value[0];
      if (tag === expected_tag) {
        let inner = value[1];
        loop$value = inner;
        loop$expected_tag = expected_tag;
        loop$expected_length = expected_length;
      } else {
        return new Error(new $gose.ParseError("invalid COSE structure"));
      }
    } else {
      return new Error(new $gose.ParseError("invalid COSE structure"));
    }
  }
}

export function parse_cose_array(data, expected_tag, expected_length) {
  return $result.try$(
    $cbor.decode(data),
    (value) => {
      return parse_cose_array_value(value, expected_tag, expected_length);
    },
  );
}

export function require_embedded_payload(payload) {
  if (payload instanceof $option.Some) {
    let p = payload[0];
    return new Ok(p);
  } else {
    return new Error(
      new $gose.InvalidState(
        "message has detached payload; use verify_detached",
      ),
    );
  }
}

export function require_detached_payload(payload) {
  if (payload instanceof $option.Some) {
    return new Error(
      new $gose.InvalidState("message has embedded payload; use verify"),
    );
  } else {
    return new Ok(undefined);
  }
}

export function build_enc_structure(context, protected_serialized, aad) {
  return $cbor.encode(
    new $cbor.Array(
      toList([
        new $cbor.Text(context),
        new $cbor.Bytes(protected_serialized),
        new $cbor.Bytes(aad),
      ]),
    ),
  );
}

export function split_ciphertext_tag(ciphertext_with_tag, tag_size) {
  let total = $bit_array.byte_size(ciphertext_with_tag);
  let ct_len = total - tag_size;
  let $ = ct_len >= 0;
  if ($) {
    let $1 = $bit_array.slice(ciphertext_with_tag, 0, ct_len);
    let $2 = $bit_array.slice(ciphertext_with_tag, ct_len, tag_size);
    if ($1 instanceof Ok && $2 instanceof Ok) {
      let ct = $1[0];
      let tag = $2[0];
      return new Ok([ct, tag]);
    } else {
      return new Error(
        new $gose.ParseError(
          "failed to split ciphertext and authentication tag",
        ),
      );
    }
  } else {
    return new Error(
      new $gose.ParseError("ciphertext too short to contain authentication tag"),
    );
  }
}
