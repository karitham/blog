import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $set from "../../../gleam_stdlib/gleam/set.mjs";
import * as $timestamp from "../../../gleam_time/gleam/time/timestamp.mjs";
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  List$Empty$const as $List$Empty$const,
  prepend as listPrepend,
  CustomType as $CustomType,
  makeError,
  isEqual,
  toBitArray,
  bitArraySlice,
  bitArraySliceToInt,
  sizedInt,
} from "../../gleam.mjs";
import * as $crypto from "../../kryptos/crypto.mjs";
import * as $ec from "../../kryptos/ec.mjs";
import * as $ecdsa from "../../kryptos/ecdsa.mjs";
import * as $eddsa from "../../kryptos/eddsa.mjs";
import * as $hash from "../../kryptos/hash.mjs";
import * as $der from "../../kryptos/internal/der.mjs";
import * as $utils from "../../kryptos/internal/utils.mjs";
import * as $x509_internal from "../../kryptos/internal/x509.mjs";
import * as $rsa from "../../kryptos/rsa.mjs";
import * as $x509 from "../../kryptos/x509.mjs";
import * as $xdh from "../../kryptos/xdh.mjs";

const FILEPATH = "src/kryptos/x509/certificate.gleam";

/**
 * Failed to parse the certificate data.
 */
export class ParseError extends $CustomType {}
export const CertificateError$ParseError$const = new ParseError();
export const CertificateError$ParseError = () =>
  CertificateError$ParseError$const;
export const CertificateError$isParseError = (value) =>
  value instanceof ParseError;

/**
 * The certificate uses an algorithm or key type that is not supported.
 */
export class UnsupportedAlgorithm extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const CertificateError$UnsupportedAlgorithm = ($0) =>
  new UnsupportedAlgorithm($0);
export const CertificateError$isUnsupportedAlgorithm = (value) =>
  value instanceof UnsupportedAlgorithm;
export const CertificateError$UnsupportedAlgorithm$0 = (value) => value[0];

/**
 * Cryptographic signature verification failed.
 */
export class SignatureVerificationFailed extends $CustomType {}
export const CertificateError$SignatureVerificationFailed$const =
  new SignatureVerificationFailed();
export const CertificateError$SignatureVerificationFailed = () =>
  CertificateError$SignatureVerificationFailed$const;
export const CertificateError$isSignatureVerificationFailed = (value) =>
  value instanceof SignatureVerificationFailed;

/**
 * The certificate contains an unrecognized extension marked as critical.
 *
 * Per RFC 5280 §4.2, certificates with unknown critical extensions must
 * be rejected. Non-critical unknown extensions are allowed.
 */
export class UnrecognizedCriticalExtension extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const CertificateError$UnrecognizedCriticalExtension = ($0) =>
  new UnrecognizedCriticalExtension($0);
export const CertificateError$isUnrecognizedCriticalExtension = (value) =>
  value instanceof UnrecognizedCriticalExtension;
export const CertificateError$UnrecognizedCriticalExtension$0 = (value) =>
  value[0];

class ExtensionsAcc extends $CustomType {
  constructor(basic_constraints, key_usage, extended_key_usage, subject_alt_names, subject_key_identifier, authority_key_identifier, raw, seen_oids) {
    super();
    this.basic_constraints = basic_constraints;
    this.key_usage = key_usage;
    this.extended_key_usage = extended_key_usage;
    this.subject_alt_names = subject_alt_names;
    this.subject_key_identifier = subject_key_identifier;
    this.authority_key_identifier = authority_key_identifier;
    this.raw = raw;
    this.seen_oids = seen_oids;
  }
}

/**
 * Automatically compute SKI as SHA-1 hash of the public key (RFC 5280 method 1).
 */
export class SkiAuto extends $CustomType {}
export const SubjectKeyIdentifierConfig$SkiAuto$const = new SkiAuto();
export const SubjectKeyIdentifierConfig$SkiAuto = () =>
  SubjectKeyIdentifierConfig$SkiAuto$const;
export const SubjectKeyIdentifierConfig$isSkiAuto = (value) =>
  value instanceof SkiAuto;

/**
 * Use a custom SKI value.
 */
export class SkiExplicit extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const SubjectKeyIdentifierConfig$SkiExplicit = ($0) =>
  new SkiExplicit($0);
export const SubjectKeyIdentifierConfig$isSkiExplicit = (value) =>
  value instanceof SkiExplicit;
export const SubjectKeyIdentifierConfig$SkiExplicit$0 = (value) => value[0];

/**
 * Automatically compute AKI as SHA-1 hash of the signing key (default).
 */
export class AkiAuto extends $CustomType {}
export const AuthorityKeyIdentifierConfig$AkiAuto$const = new AkiAuto();
export const AuthorityKeyIdentifierConfig$AkiAuto = () =>
  AuthorityKeyIdentifierConfig$AkiAuto$const;
export const AuthorityKeyIdentifierConfig$isAkiAuto = (value) =>
  value instanceof AkiAuto;

/**
 * Use a custom AKI keyIdentifier value.
 */
export class AkiExplicit extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const AuthorityKeyIdentifierConfig$AkiExplicit = ($0) =>
  new AkiExplicit($0);
export const AuthorityKeyIdentifierConfig$isAkiExplicit = (value) =>
  value instanceof AkiExplicit;
export const AuthorityKeyIdentifierConfig$AkiExplicit$0 = (value) => value[0];

/**
 * Exclude the AKI extension entirely.
 */
export class AkiExclude extends $CustomType {}
export const AuthorityKeyIdentifierConfig$AkiExclude$const = new AkiExclude();
export const AuthorityKeyIdentifierConfig$AkiExclude = () =>
  AuthorityKeyIdentifierConfig$AkiExclude$const;
export const AuthorityKeyIdentifierConfig$isAkiExclude = (value) =>
  value instanceof AkiExclude;

class BuiltCertificate extends $CustomType {
  constructor(der) {
    super();
    this.der = der;
  }
}

class ParsedCertificate extends $CustomType {
  constructor(der, tbs_bytes, signature, version, serial_number, signature_algorithm, issuer, validity, subject, public_key, basic_constraints, key_usage, extended_key_usage, subject_alt_names, subject_key_identifier, authority_key_identifier, extensions) {
    super();
    this.der = der;
    this.tbs_bytes = tbs_bytes;
    this.signature = signature;
    this.version = version;
    this.serial_number = serial_number;
    this.signature_algorithm = signature_algorithm;
    this.issuer = issuer;
    this.validity = validity;
    this.subject = subject;
    this.public_key = public_key;
    this.basic_constraints = basic_constraints;
    this.key_usage = key_usage;
    this.extended_key_usage = extended_key_usage;
    this.subject_alt_names = subject_alt_names;
    this.subject_key_identifier = subject_key_identifier;
    this.authority_key_identifier = authority_key_identifier;
    this.extensions = extensions;
  }
}

class Builder extends $CustomType {
  constructor(subject, validity, basic_constraints, key_usage, extended_key_usage, subject_alt_names, serial_number, subject_key_identifier, authority_key_identifier) {
    super();
    this.subject = subject;
    this.validity = validity;
    this.basic_constraints = basic_constraints;
    this.key_usage = key_usage;
    this.extended_key_usage = extended_key_usage;
    this.subject_alt_names = subject_alt_names;
    this.serial_number = serial_number;
    this.subject_key_identifier = subject_key_identifier;
    this.authority_key_identifier = authority_key_identifier;
  }
}

const oid_authority_key_identifier = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([2, 5, 29, 35]),
);

const oid_subject_key_identifier = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([2, 5, 29, 14]),
);

const oid_ocsp_signing = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 3, 6, 1, 5, 5, 7, 3, 9]),
);

const oid_email_protection = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 3, 6, 1, 5, 5, 7, 3, 4]),
);

const oid_code_signing = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 3, 6, 1, 5, 5, 7, 3, 3]),
);

const oid_client_auth = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 3, 6, 1, 5, 5, 7, 3, 2]),
);

const oid_server_auth = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 3, 6, 1, 5, 5, 7, 3, 1]),
);

const oid_extended_key_usage = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([2, 5, 29, 37]),
);

const key_usages = /* @__PURE__ */ toList([
  $x509.KeyUsage$DigitalSignature$const,
  $x509.KeyUsage$NonRepudiation$const,
  $x509.KeyUsage$KeyEncipherment$const,
  $x509.KeyUsage$DataEncipherment$const,
  $x509.KeyUsage$KeyAgreement$const,
  $x509.KeyUsage$KeyCertSign$const,
  $x509.KeyUsage$CrlSign$const,
  $x509.KeyUsage$EncipherOnly$const,
  $x509.KeyUsage$DecipherOnly$const,
]);

const oid_key_usage = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([2, 5, 29, 15]),
);

const oid_basic_constraints = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([2, 5, 29, 19]),
);

const oid_ed448 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 3, 101, 113]),
);

const oid_ed25519 = /* @__PURE__ */ new $x509.Oid(
  /* @__PURE__ */ toList([1, 3, 101, 112]),
);

const pem_end = "-----END CERTIFICATE-----";

const pem_begin = "-----BEGIN CERTIFICATE-----";

function empty_extensions_acc() {
  return new ExtensionsAcc(
    $option.Option$None$const,
    $List$Empty$const,
    $List$Empty$const,
    $List$Empty$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $List$Empty$const,
    $set.new$(),
  );
}

/**
 * Creates a new certificate builder with default values.
 *
 * Use the `with_*` functions to configure the builder, then call
 * a signing function to generate the certificate.
 */
export function new$() {
  return new Builder(
    $x509.name($List$Empty$const),
    $option.Option$None$const,
    $option.Option$None$const,
    $List$Empty$const,
    $List$Empty$const,
    $List$Empty$const,
    $option.Option$None$const,
    $option.Option$None$const,
    AuthorityKeyIdentifierConfig$AkiAuto$const,
  );
}

/**
 * Sets the distinguished name subject for the certificate.
 */
export function with_subject(builder, subject) {
  return new Builder(
    subject,
    builder.validity,
    builder.basic_constraints,
    builder.key_usage,
    builder.extended_key_usage,
    builder.subject_alt_names,
    builder.serial_number,
    builder.subject_key_identifier,
    builder.authority_key_identifier,
  );
}

/**
 * Sets the validity period for the certificate.
 */
export function with_validity(builder, validity) {
  return new Builder(
    builder.subject,
    new $option.Some(validity),
    builder.basic_constraints,
    builder.key_usage,
    builder.extended_key_usage,
    builder.subject_alt_names,
    builder.serial_number,
    builder.subject_key_identifier,
    builder.authority_key_identifier,
  );
}

/**
 * Sets the Basic Constraints extension.
 *
 * This extension indicates whether the certificate is a CA certificate
 * and optionally limits the path length of the certification chain.
 * Per RFC 5280, path_len_constraint is only meaningful when ca is True.
 */
export function with_basic_constraints(builder, ca, path_len_constraint) {
  let _block;
  if (ca) {
    _block = path_len_constraint;
  } else {
    _block = $option.Option$None$const;
  }
  let effective_path_len = _block;
  return new Builder(
    builder.subject,
    builder.validity,
    new $option.Some([ca, effective_path_len]),
    builder.key_usage,
    builder.extended_key_usage,
    builder.subject_alt_names,
    builder.serial_number,
    builder.subject_key_identifier,
    builder.authority_key_identifier,
  );
}

/**
 * Adds a Key Usage flag to the certificate.
 *
 * Multiple usages can be added by chaining calls.
 */
export function with_key_usage(builder, usage) {
  return new Builder(
    builder.subject,
    builder.validity,
    builder.basic_constraints,
    listPrepend(usage, builder.key_usage),
    builder.extended_key_usage,
    builder.subject_alt_names,
    builder.serial_number,
    builder.subject_key_identifier,
    builder.authority_key_identifier,
  );
}

/**
 * Adds an Extended Key Usage purpose to the certificate.
 *
 * EKU narrows allowed purposes beyond Key Usage (e.g., ServerAuth,
 * CodeSigning). Multiple usages can be added by chaining calls.
 */
export function with_extended_key_usage(builder, usage) {
  return new Builder(
    builder.subject,
    builder.validity,
    builder.basic_constraints,
    builder.key_usage,
    listPrepend(usage, builder.extended_key_usage),
    builder.subject_alt_names,
    builder.serial_number,
    builder.subject_key_identifier,
    builder.authority_key_identifier,
  );
}

/**
 * Adds a DNS name to the Subject Alternative Names extension.
 *
 * The name must contain only ASCII characters.
 */
export function with_dns_name(builder, name) {
  let $ = $utils.is_ascii(name);
  if ($) {
    let _pipe = new Builder(
      builder.subject,
      builder.validity,
      builder.basic_constraints,
      builder.key_usage,
      builder.extended_key_usage,
      listPrepend(new $x509.DnsName(name), builder.subject_alt_names),
      builder.serial_number,
      builder.subject_key_identifier,
      builder.authority_key_identifier,
    );
    return new Ok(_pipe);
  } else {
    return new Error(undefined);
  }
}

/**
 * Adds an email address to the Subject Alternative Names extension.
 *
 * The email must contain only ASCII characters.
 */
export function with_email(builder, email) {
  let $ = $utils.is_ascii(email);
  if ($) {
    let _pipe = new Builder(
      builder.subject,
      builder.validity,
      builder.basic_constraints,
      builder.key_usage,
      builder.extended_key_usage,
      listPrepend(new $x509.Email(email), builder.subject_alt_names),
      builder.serial_number,
      builder.subject_key_identifier,
      builder.authority_key_identifier,
    );
    return new Ok(_pipe);
  } else {
    return new Error(undefined);
  }
}

/**
 * Adds an IP address to the Subject Alternative Names extension.
 *
 * Accepts IPv4 (e.g., "192.168.1.1") or IPv6 (e.g., "2001:db8::1") addresses.
 */
export function with_ip(builder, ip) {
  let _pipe = $utils.parse_ip(ip);
  return $result.map(
    _pipe,
    (parsed) => {
      return new Builder(
        builder.subject,
        builder.validity,
        builder.basic_constraints,
        builder.key_usage,
        builder.extended_key_usage,
        listPrepend(new $x509.IpAddress(parsed), builder.subject_alt_names),
        builder.serial_number,
        builder.subject_key_identifier,
        builder.authority_key_identifier,
      );
    },
  );
}

/**
 * Sets the serial number for the certificate.
 *
 * If not set, a random serial number will be generated during signing.
 */
export function with_serial_number(builder, serial) {
  return new Builder(
    builder.subject,
    builder.validity,
    builder.basic_constraints,
    builder.key_usage,
    builder.extended_key_usage,
    builder.subject_alt_names,
    new $option.Some(serial),
    builder.subject_key_identifier,
    builder.authority_key_identifier,
  );
}

/**
 * Enables the Subject Key Identifier extension in the certificate.
 *
 * If not called, the SKI extension will not be included. Use `SkiAuto` to
 * compute from the public key (SHA-1 hash per RFC 5280 method 1) or
 * `SkiExplicit(bytes)` for a custom value.
 */
export function with_subject_key_identifier(builder, ski) {
  return new Builder(
    builder.subject,
    builder.validity,
    builder.basic_constraints,
    builder.key_usage,
    builder.extended_key_usage,
    builder.subject_alt_names,
    builder.serial_number,
    new $option.Some(ski),
    builder.authority_key_identifier,
  );
}

/**
 * Configures the Authority Key Identifier extension for the certificate.
 *
 * By default, self-signed certificates include an AKI with keyIdentifier
 * computed as the SHA-1 hash of the signing public key. Use `AkiExplicit`
 * for a custom value or `AkiExclude` to omit the extension.
 */
export function with_authority_key_identifier(builder, aki) {
  return new Builder(
    builder.subject,
    builder.validity,
    builder.basic_constraints,
    builder.key_usage,
    builder.extended_key_usage,
    builder.subject_alt_names,
    builder.serial_number,
    builder.subject_key_identifier,
    aki,
  );
}

/**
 * Generates a random 20-byte serial number with the high bit cleared per RFC 5280.
 */
export function generate_serial_number() {
  let bytes = $crypto.random_bytes(20);
  let first;
  let rest;
  if (bytes.bitSize >= 8) {
    first = bytes.byteAt(0);
    rest = bitArraySlice(bytes, 8);
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      372,
      "generate_serial_number",
      "Pattern match failed, no pattern matched the value.",
      {
        value: bytes,
        start: 11779,
        end: 11820,
        pattern_start: 11790,
        pattern_end: 11812
      }
    )
  }
  return toBitArray([$int.bitwise_and(first, 0x7f), rest]);
}

function encode_certificate(tbs, sig_alg, signature) {
  return $result.try$(
    $x509_internal.encode_algorithm_identifier(sig_alg),
    (sig_alg_der) => {
      return $result.try$(
        $der.encode_bit_string(signature),
        (sig_bits) => {
          return $der.encode_sequence(
            $bit_array.concat(toList([tbs, sig_alg_der, sig_bits])),
          );
        },
      );
    },
  );
}

function encode_authority_key_identifier_extension(key_identifier) {
  let $ = oid_authority_key_identifier;
  let oid_components = $.components;
  return $result.try$(
    $der.encode_oid(oid_components),
    (oid_encoded) => {
      let _pipe = key_identifier;
      let _pipe$1 = ((_capture) => {
        return $der.encode_context_primitive_tag(0, _capture);
      })(_pipe);
      let _pipe$2 = $result.try$(_pipe$1, $der.encode_sequence);
      let _pipe$3 = $result.try$(_pipe$2, $der.encode_octet_string);
      let _pipe$4 = $result.map(
        _pipe$3,
        (value_octet) => {
          return $bit_array.concat(toList([oid_encoded, value_octet]));
        },
      );
      return $result.try$(_pipe$4, $der.encode_sequence);
    },
  );
}

function compute_ski(spki) {
  let _pipe = spki;
  let _pipe$1 = $x509_internal.extract_spki_public_key_bytes(_pipe);
  return $result.try$(
    _pipe$1,
    (_capture) => {
      return $crypto.hash($hash.HashAlgorithm$Sha1$const, _capture);
    },
  );
}

function encode_aki_opt(config, spki) {
  if (config instanceof AkiAuto) {
    let _pipe = compute_ski(spki);
    let _pipe$1 = $result.try$(_pipe, encode_authority_key_identifier_extension);
    return $result.map(_pipe$1, (var0) => { return new Ok(var0); });
  } else if (config instanceof AkiExplicit) {
    let key_id = config[0];
    let _pipe = encode_authority_key_identifier_extension(key_id);
    return $result.map(_pipe, (var0) => { return new Ok(var0); });
  } else {
    return new Ok(new Error(undefined));
  }
}

function encode_subject_key_identifier_extension(ski) {
  let $ = oid_subject_key_identifier;
  let oid_components = $.components;
  return $result.try$(
    $der.encode_oid(oid_components),
    (oid_encoded) => {
      let _pipe = ski;
      let _pipe$1 = $der.encode_octet_string(_pipe);
      let _pipe$2 = $result.try$(_pipe$1, $der.encode_octet_string);
      let _pipe$3 = $result.map(
        _pipe$2,
        (value_octet) => {
          return $bit_array.concat(toList([oid_encoded, value_octet]));
        },
      );
      return $result.try$(_pipe$3, $der.encode_sequence);
    },
  );
}

function encode_ski_opt(config, spki) {
  if (config instanceof $option.Some) {
    let $ = config[0];
    if ($ instanceof SkiAuto) {
      let _pipe = compute_ski(spki);
      let _pipe$1 = $result.try$(_pipe, encode_subject_key_identifier_extension);
      return $result.map(_pipe$1, (var0) => { return new Ok(var0); });
    } else {
      let ski = $[0];
      let _pipe = encode_subject_key_identifier_extension(ski);
      return $result.map(_pipe, (var0) => { return new Ok(var0); });
    }
  } else {
    return new Ok(new Error(undefined));
  }
}

function encode_san_opt(sans, critical) {
  return $bool.guard(
    $list.is_empty(sans),
    new Ok(new Error(undefined)),
    () => {
      return $result.map(
        $x509_internal.encode_san_extension(sans, critical),
        (var0) => { return new Ok(var0); },
      );
    },
  );
}

function encode_extended_key_usage_extension(usages) {
  let $ = oid_extended_key_usage;
  let oid_components = $.components;
  return $result.try$(
    $der.encode_oid(oid_components),
    (oid_encoded) => {
      let _pipe = usages;
      let _pipe$1 = $list.try_map(
        _pipe,
        (usage) => {
          let _block;
          if (usage instanceof $x509.ServerAuth) {
            _block = oid_server_auth;
          } else if (usage instanceof $x509.ClientAuth) {
            _block = oid_client_auth;
          } else if (usage instanceof $x509.CodeSigning) {
            _block = oid_code_signing;
          } else if (usage instanceof $x509.EmailProtection) {
            _block = oid_email_protection;
          } else {
            _block = oid_ocsp_signing;
          }
          let $1 = _block;
          let components = $1.components;
          return $der.encode_oid(components);
        },
      );
      let _pipe$2 = $result.map(_pipe$1, $bit_array.concat);
      let _pipe$3 = $result.try$(_pipe$2, $der.encode_sequence);
      let _pipe$4 = $result.try$(_pipe$3, $der.encode_octet_string);
      let _pipe$5 = $result.map(
        _pipe$4,
        (value_octet) => {
          return $bit_array.concat(toList([oid_encoded, value_octet]));
        },
      );
      return $result.try$(_pipe$5, $der.encode_sequence);
    },
  );
}

function encode_extended_key_usage_opt(usages) {
  return $bool.guard(
    $list.is_empty(usages),
    new Ok(new Error(undefined)),
    () => {
      return $result.map(
        encode_extended_key_usage_extension(usages),
        (var0) => { return new Ok(var0); },
      );
    },
  );
}

function encode_key_usage_extension(usages) {
  let $ = oid_key_usage;
  let oid_components = $.components;
  return $result.try$(
    $der.encode_oid(oid_components),
    (oid_encoded) => {
      let last_set_index = $list.index_fold(
        key_usages,
        0,
        (last_index, usage, index) => {
          let $1 = $list.contains(usages, usage);
          if ($1) {
            return index + 1;
          } else {
            return last_index;
          }
        },
      );
      let _block;
      let _pipe = key_usages;
      let _pipe$1 = $list.take(_pipe, last_set_index);
      _block = $list.fold(
        _pipe$1,
        toBitArray([]),
        (acc, usage) => {
          let _block$1;
          let $1 = $list.contains(usages, usage);
          if ($1) {
            _block$1 = 1;
          } else {
            _block$1 = 0;
          }
          let bit = _block$1;
          return toBitArray([acc, sizedInt(bit, 1, true)]);
        },
      );
      let key_usage_bits = _block;
      let _pipe$2 = key_usage_bits;
      let _pipe$3 = $der.encode_bit_string(_pipe$2);
      let _pipe$4 = $result.try$(_pipe$3, $der.encode_octet_string);
      let _pipe$5 = $result.map(
        _pipe$4,
        (value_octet) => {
          return $bit_array.concat(
            toList([oid_encoded, $der.encode_bool(true), value_octet]),
          );
        },
      );
      return $result.try$(_pipe$5, $der.encode_sequence);
    },
  );
}

function encode_key_usage_opt(usages) {
  return $bool.guard(
    $list.is_empty(usages),
    new Ok(new Error(undefined)),
    () => {
      return $result.map(
        encode_key_usage_extension(usages),
        (var0) => { return new Ok(var0); },
      );
    },
  );
}

function encode_basic_constraints_extension(ca, path_len) {
  let $ = oid_basic_constraints;
  let oid_components = $.components;
  return $result.try$(
    $der.encode_oid(oid_components),
    (oid_encoded) => {
      let _block;
      if (ca) {
        _block = $der.encode_bool(true);
      } else {
        _block = toBitArray([]);
      }
      let ca_bool = _block;
      let _block$1;
      if (path_len instanceof $option.Some) {
        let n = path_len[0];
        _block$1 = $der.encode_small_int(n);
      } else {
        _block$1 = new Ok(toBitArray([]));
      }
      let _pipe = _block$1;
      let _pipe$1 = $result.map(
        _pipe,
        (path_len_int) => {
          return $bit_array.concat(toList([ca_bool, path_len_int]));
        },
      );
      let _pipe$2 = $result.try$(_pipe$1, $der.encode_sequence);
      let _pipe$3 = $result.try$(_pipe$2, $der.encode_octet_string);
      let _pipe$4 = $result.map(
        _pipe$3,
        (value_octet) => {
          return $bit_array.concat(
            toList([oid_encoded, $der.encode_bool(true), value_octet]),
          );
        },
      );
      return $result.try$(_pipe$4, $der.encode_sequence);
    },
  );
}

function encode_basic_constraints_opt(config) {
  if (config instanceof $option.Some) {
    let ca = config[0][0];
    let path_len = config[0][1];
    return $result.map(
      encode_basic_constraints_extension(ca, path_len),
      (var0) => { return new Ok(var0); },
    );
  } else {
    return new Ok(new Error(undefined));
  }
}

function encode_extensions(builder, spki) {
  let $ = builder.subject;
  let rdns = $.rdns;
  let subject_is_empty = $list.is_empty(rdns);
  let sans_is_empty = $list.is_empty(builder.subject_alt_names);
  return $bool.guard(
    subject_is_empty && sans_is_empty,
    new Error(undefined),
    () => {
      let extension_results = toList([
        encode_basic_constraints_opt(builder.basic_constraints),
        encode_key_usage_opt(builder.key_usage),
        encode_extended_key_usage_opt(builder.extended_key_usage),
        encode_san_opt(builder.subject_alt_names, subject_is_empty),
        encode_ski_opt(builder.subject_key_identifier, spki),
        encode_aki_opt(builder.authority_key_identifier, spki),
      ]);
      return $result.try$(
        $result.all(extension_results),
        (results) => {
          let encoded = $result.values(results);
          if (encoded instanceof $Empty) {
            return new Ok(toBitArray([]));
          } else {
            let _pipe = encoded;
            let _pipe$1 = $bit_array.concat(_pipe);
            let _pipe$2 = $der.encode_sequence(_pipe$1);
            return $result.try$(
              _pipe$2,
              (_capture) => { return $der.encode_context_tag(3, _capture); },
            );
          }
        },
      );
    },
  );
}

function encode_validity(validity) {
  let not_before = validity.not_before;
  let not_after = validity.not_after;
  return $result.try$(
    $der.encode_timestamp(not_before),
    (not_before_der) => {
      return $result.try$(
        $der.encode_timestamp(not_after),
        (not_after_der) => {
          return $der.encode_sequence(
            $bit_array.concat(toList([not_before_der, not_after_der])),
          );
        },
      );
    },
  );
}

function encode_version() {
  let _pipe = $der.encode_integer(toBitArray([2]));
  return $result.try$(
    _pipe,
    (_capture) => { return $der.encode_context_tag(0, _capture); },
  );
}

function encode_tbs_certificate(builder, serial, sig_alg, spki, validity) {
  return $result.try$(
    encode_version(),
    (version) => {
      return $result.try$(
        $der.encode_integer(serial),
        (serial_int) => {
          return $result.try$(
            $x509_internal.encode_algorithm_identifier(sig_alg),
            (sig_alg_der) => {
              return $result.try$(
                $x509_internal.encode_name(builder.subject),
                (issuer) => {
                  return $result.try$(
                    encode_validity(validity),
                    (validity_der) => {
                      return $result.try$(
                        $x509_internal.encode_name(builder.subject),
                        (subject) => {
                          return $result.try$(
                            encode_extensions(builder, spki),
                            (extensions) => {
                              return $der.encode_sequence(
                                $bit_array.concat(
                                  toList([
                                    version,
                                    serial_int,
                                    sig_alg_der,
                                    issuer,
                                    validity_der,
                                    subject,
                                    spki,
                                    extensions,
                                  ]),
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
 * Signs a self-signed certificate with an ECDSA private key.
 *
 * The public key is derived from the private key and used as both
 * the issuer and subject public key.
 */
export function self_signed_with_ecdsa(builder, key, hash) {
  return $result.try$(
    $option.to_result(builder.validity, undefined),
    (validity) => {
      return $result.try$(
        $x509_internal.ecdsa_sig_alg_info(hash),
        (sig_alg) => {
          let public_key$1 = $ec.public_key_from_private_key(key);
          return $result.try$(
            $ec.public_key_to_der(public_key$1),
            (spki) => {
              let _block;
              let $ = builder.serial_number;
              if ($ instanceof $option.Some) {
                let s = $[0];
                _block = s;
              } else {
                _block = generate_serial_number();
              }
              let serial = _block;
              return $result.try$(
                encode_tbs_certificate(builder, serial, sig_alg, spki, validity),
                (tbs) => {
                  let signature = $ecdsa.sign(key, tbs, hash);
                  return $result.try$(
                    encode_certificate(tbs, sig_alg, signature),
                    (cert_der) => {
                      return new Ok(new BuiltCertificate(cert_der));
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
 * Signs a self-signed certificate with an RSA private key using PKCS#1 v1.5 padding.
 *
 * The public key is derived from the private key and used as both
 * the issuer and subject public key.
 */
export function self_signed_with_rsa(builder, key, hash) {
  return $result.try$(
    $option.to_result(builder.validity, undefined),
    (validity) => {
      return $result.try$(
        $x509_internal.rsa_sig_alg_info(hash),
        (sig_alg) => {
          let public_key$1 = $rsa.public_key_from_private_key(key);
          return $result.try$(
            $rsa.public_key_to_der(
              public_key$1,
              $rsa.PublicKeyFormat$Spki$const,
            ),
            (spki) => {
              let _block;
              let $ = builder.serial_number;
              if ($ instanceof $option.Some) {
                let s = $[0];
                _block = s;
              } else {
                _block = generate_serial_number();
              }
              let serial = _block;
              return $result.try$(
                encode_tbs_certificate(builder, serial, sig_alg, spki, validity),
                (tbs) => {
                  let signature = $rsa.sign(
                    key,
                    tbs,
                    hash,
                    $rsa.SignPadding$Pkcs1v15$const,
                  );
                  return $result.try$(
                    encode_certificate(tbs, sig_alg, signature),
                    (cert_der) => {
                      return new Ok(new BuiltCertificate(cert_der));
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
 * Signs a self-signed certificate with an EdDSA private key.
 *
 * The public key is derived from the private key and used as both
 * the issuer and subject public key. EdDSA has built-in hashing, so no
 * hash algorithm parameter is needed.
 */
export function self_signed_with_eddsa(builder, key) {
  return $result.try$(
    $option.to_result(builder.validity, undefined),
    (validity) => {
      let _block;
      let $ = $eddsa.curve(key);
      if ($ instanceof $eddsa.Ed25519) {
        _block = new $x509_internal.SigAlgInfo(oid_ed25519, false);
      } else {
        _block = new $x509_internal.SigAlgInfo(oid_ed448, false);
      }
      let sig_alg = _block;
      let public_key$1 = $eddsa.public_key_from_private_key(key);
      return $result.try$(
        $eddsa.public_key_to_der(public_key$1),
        (spki) => {
          let _block$1;
          let $1 = builder.serial_number;
          if ($1 instanceof $option.Some) {
            let s = $1[0];
            _block$1 = s;
          } else {
            _block$1 = generate_serial_number();
          }
          let serial = _block$1;
          return $result.try$(
            encode_tbs_certificate(builder, serial, sig_alg, spki, validity),
            (tbs) => {
              let signature = $eddsa.sign(key, tbs);
              return $result.try$(
                encode_certificate(tbs, sig_alg, signature),
                (cert_der) => { return new Ok(new BuiltCertificate(cert_der)); },
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Exports the certificate as DER-encoded bytes.
 */
export function to_der(cert) {
  if (cert instanceof BuiltCertificate) {
    let der = cert.der;
    return der;
  } else {
    let der = cert.der;
    return der;
  }
}

/**
 * Exports the certificate as a PEM-encoded string.
 */
export function to_pem(cert) {
  return $x509_internal.encode_pem(to_der(cert), pem_begin, pem_end);
}

function parse_aki_fields(bytes, key_id, issuer, serial) {
  if (bytes.bitSize === 0) {
    return new Ok(new $x509.AuthorityKeyIdentifier(key_id, issuer, serial));
  } else if (bytes.bitSize >= 8) {
    if (bytes.byteAt(0) === 128) {
      if (bytes.bitSize >= 16) {
        let len = bytes.byteAt(1);
        let rest = bitArraySlice(bytes, 16);
        return $bool.guard(
          $bit_array.byte_size(rest) < len,
          new Error(undefined),
          () => {
            return $result.try$(
              $bit_array.slice(rest, 0, len),
              (key_bytes) => {
                return $result.try$(
                  $bit_array.slice(rest, len, $bit_array.byte_size(rest) - len),
                  (remaining) => {
                    return parse_aki_fields(
                      remaining,
                      new $option.Some(key_bytes),
                      issuer,
                      serial,
                    );
                  },
                );
              },
            );
          },
        );
      } else {
        return new Error(undefined);
      }
    } else if (bytes.byteAt(0) === 161) {
      return $result.try$(
        $der.parse_context_tag(bytes, 1),
        (_use0) => {
          let issuer_content = _use0[0];
          let remaining = _use0[1];
          return $result.try$(
            $x509_internal.parse_general_names(
              issuer_content,
              $List$Empty$const,
              false,
            ),
            (parsed_issuers) => {
              return parse_aki_fields(
                remaining,
                key_id,
                new $option.Some(parsed_issuers),
                serial,
              );
            },
          );
        },
      );
    } else if (bytes.byteAt(0) === 130 && bytes.bitSize >= 16) {
      let len = bytes.byteAt(1);
      let rest = bitArraySlice(bytes, 16);
      return $bool.guard(
        $bit_array.byte_size(rest) < len,
        new Error(undefined),
        () => {
          return $result.try$(
            $bit_array.slice(rest, 0, len),
            (serial_bytes) => {
              return $result.try$(
                $bit_array.slice(rest, len, $bit_array.byte_size(rest) - len),
                (remaining) => {
                  return parse_aki_fields(
                    remaining,
                    key_id,
                    issuer,
                    new $option.Some(serial_bytes),
                  );
                },
              );
            },
          );
        },
      );
    } else {
      return new Error(undefined);
    }
  } else {
    return new Error(undefined);
  }
}

function parse_authority_key_identifier_ext(bytes) {
  return $result.try$(
    $der.parse_sequence(bytes),
    (_use0) => {
      let inner = _use0[0];
      let remaining = _use0[1];
      return $bool.guard(
        !isEqual(remaining, toBitArray([])),
        new Error(undefined),
        () => {
          return parse_aki_fields(
            inner,
            $option.Option$None$const,
            $option.Option$None$const,
            $option.Option$None$const,
          );
        },
      );
    },
  );
}

function parse_subject_key_identifier_ext(bytes) {
  return $result.try$(
    $der.parse_octet_string(bytes),
    (_use0) => {
      let value = _use0[0];
      let remaining = _use0[1];
      return $bool.guard(
        !isEqual(remaining, toBitArray([])),
        new Error(undefined),
        () => { return new Ok(value); },
      );
    },
  );
}

function parse_eku_oids(bytes, acc, is_critical) {
  if (bytes.bitSize === 0) {
    return new Ok($list.reverse(acc));
  } else {
    return $result.try$(
      (() => {
        let _pipe = $der.parse_oid(bytes);
        return $result.replace_error(_pipe, CertificateError$ParseError$const);
      })(),
      (_use0) => {
        let oid_components = _use0[0];
        let rest = _use0[1];
        let _block;
        if (oid_components instanceof $Empty) {
          _block = $option.Option$None$const;
        } else {
          let $ = oid_components.tail;
          if ($ instanceof $Empty) {
            _block = $option.Option$None$const;
          } else {
            let $1 = $.tail;
            if ($1 instanceof $Empty) {
              _block = $option.Option$None$const;
            } else {
              let $2 = $1.tail;
              if ($2 instanceof $Empty) {
                _block = $option.Option$None$const;
              } else {
                let $3 = $2.tail;
                if ($3 instanceof $Empty) {
                  _block = $option.Option$None$const;
                } else {
                  let $4 = $3.tail;
                  if ($4 instanceof $Empty) {
                    _block = $option.Option$None$const;
                  } else {
                    let $5 = $4.tail;
                    if ($5 instanceof $Empty) {
                      _block = $option.Option$None$const;
                    } else {
                      let $6 = $5.tail;
                      if ($6 instanceof $Empty) {
                        _block = $option.Option$None$const;
                      } else {
                        let $7 = $6.tail;
                        if ($7 instanceof $Empty) {
                          _block = $option.Option$None$const;
                        } else {
                          let $8 = $7.tail;
                          if ($8 instanceof $Empty) {
                            let $9 = oid_components.head;
                            if ($9 === 1) {
                              let $10 = $.head;
                              if ($10 === 3) {
                                let $11 = $1.head;
                                if ($11 === 6) {
                                  let $12 = $2.head;
                                  if ($12 === 1) {
                                    let $13 = $3.head;
                                    if ($13 === 5) {
                                      let $14 = $4.head;
                                      if ($14 === 5) {
                                        let $15 = $5.head;
                                        if ($15 === 7) {
                                          let $16 = $6.head;
                                          if ($16 === 3) {
                                            let $17 = $7.head;
                                            if ($17 === 1) {
                                              _block = new $option.Some(
                                                $x509.ExtendedKeyUsage$ServerAuth$const,
                                              );
                                            } else if ($17 === 2) {
                                              _block = new $option.Some(
                                                $x509.ExtendedKeyUsage$ClientAuth$const,
                                              );
                                            } else if ($17 === 3) {
                                              _block = new $option.Some(
                                                $x509.ExtendedKeyUsage$CodeSigning$const,
                                              );
                                            } else if ($17 === 4) {
                                              _block = new $option.Some(
                                                $x509.ExtendedKeyUsage$EmailProtection$const,
                                              );
                                            } else if ($17 === 9) {
                                              _block = new $option.Some(
                                                $x509.ExtendedKeyUsage$OcspSigning$const,
                                              );
                                            } else {
                                              _block = $option.Option$None$const;
                                            }
                                          } else {
                                            _block = $option.Option$None$const;
                                          }
                                        } else {
                                          _block = $option.Option$None$const;
                                        }
                                      } else {
                                        _block = $option.Option$None$const;
                                      }
                                    } else {
                                      _block = $option.Option$None$const;
                                    }
                                  } else {
                                    _block = $option.Option$None$const;
                                  }
                                } else {
                                  _block = $option.Option$None$const;
                                }
                              } else {
                                _block = $option.Option$None$const;
                              }
                            } else {
                              _block = $option.Option$None$const;
                            }
                          } else {
                            _block = $option.Option$None$const;
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        let eku = _block;
        if (eku instanceof $option.Some) {
          let e = eku[0];
          return parse_eku_oids(rest, listPrepend(e, acc), is_critical);
        } else if (is_critical) {
          return new Error(
            new UnrecognizedCriticalExtension(new $x509.Oid(oid_components)),
          );
        } else {
          return parse_eku_oids(rest, acc, is_critical);
        }
      },
    );
  }
}

function parse_extended_key_usage_ext(bytes, is_critical) {
  return $result.try$(
    (() => {
      let _pipe = $der.parse_sequence(bytes);
      return $result.replace_error(_pipe, CertificateError$ParseError$const);
    })(),
    (_use0) => {
      let seq_content = _use0[0];
      return parse_eku_oids(seq_content, $List$Empty$const, is_critical);
    },
  );
}

function decode_key_usage_bits(bytes) {
  if (
    bytes.bitSize >= 1 &&
    bytes.bitSize >= 2 &&
    bytes.bitSize >= 3 &&
    bytes.bitSize >= 4 &&
    bytes.bitSize >= 5 &&
    bytes.bitSize >= 6 &&
    bytes.bitSize >= 7 &&
    bytes.bitSize >= 8
  ) {
    let digital_signature = bitArraySliceToInt(bytes, 0, 1, true, false);
    let non_repudiation = bitArraySliceToInt(bytes, 1, 2, true, false);
    let key_encipherment = bitArraySliceToInt(bytes, 2, 3, true, false);
    let data_encipherment = bitArraySliceToInt(bytes, 3, 4, true, false);
    let key_agreement = bitArraySliceToInt(bytes, 4, 5, true, false);
    let key_cert_sign = bitArraySliceToInt(bytes, 5, 6, true, false);
    let crl_sign = bitArraySliceToInt(bytes, 6, 7, true, false);
    let encipher_only = bitArraySliceToInt(bytes, 7, 8, true, false);
    let rest = bitArraySlice(bytes, 8);
    let _block;
    let _pipe = toList([
      [digital_signature, $x509.KeyUsage$DigitalSignature$const],
      [non_repudiation, $x509.KeyUsage$NonRepudiation$const],
      [key_encipherment, $x509.KeyUsage$KeyEncipherment$const],
      [data_encipherment, $x509.KeyUsage$DataEncipherment$const],
      [key_agreement, $x509.KeyUsage$KeyAgreement$const],
      [key_cert_sign, $x509.KeyUsage$KeyCertSign$const],
      [crl_sign, $x509.KeyUsage$CrlSign$const],
      [encipher_only, $x509.KeyUsage$EncipherOnly$const],
    ]);
    _block = $list.filter_map(
      _pipe,
      (pair) => {
        let bit = pair[0];
        let usage = pair[1];
        let $ = bit === 1;
        if ($) {
          return new Ok(usage);
        } else {
          return new Error(undefined);
        }
      },
    );
    let usages = _block;
    if (rest.bitSize >= 1 && bitArraySliceToInt(rest, 0, 1, true, false) === 1) {
      return listPrepend($x509.KeyUsage$DecipherOnly$const, usages);
    } else {
      return usages;
    }
  } else {
    return $List$Empty$const;
  }
}

function parse_key_usage_ext(bytes) {
  if (
    bytes.bitSize >= 8 &&
    bytes.byteAt(0) === 3 &&
    bytes.bitSize >= 16 &&
    bytes.bitSize >= 24
  ) {
    let len = bytes.byteAt(1);
    let unused_bits = bytes.byteAt(2);
    if ((unused_bits <= 7) && (len >= 2)) {
      let rest = bitArraySlice(bytes, 24);
      let _pipe = $bit_array.slice(rest, 0, len - 1);
      return $result.map(_pipe, decode_key_usage_bits);
    } else {
      return new Error(undefined);
    }
  } else {
    return new Error(undefined);
  }
}

function bytes_to_int(bytes) {
  if (bytes.bitSize === 8) {
    let n = bytes.byteAt(0);
    return new Ok(n);
  } else if (bytes.bitSize === 16) {
    let n = bitArraySliceToInt(bytes, 0, 16, true, false);
    return new Ok(n);
  } else if (bytes.bitSize === 24) {
    let n = bitArraySliceToInt(bytes, 0, 24, true, false);
    return new Ok(n);
  } else if (bytes.bitSize === 32) {
    let n = bitArraySliceToInt(bytes, 0, 32, true, false);
    return new Ok(n);
  } else {
    return new Error(undefined);
  }
}

function parse_basic_constraints_ext(bytes) {
  return $result.try$(
    $der.parse_sequence(bytes),
    (_use0) => {
      let seq_content = _use0[0];
      let remaining = _use0[1];
      return $bool.guard(
        !isEqual(remaining, toBitArray([])),
        new Error(undefined),
        () => {
          return $bool.guard(
            $bit_array.byte_size(seq_content) === 0,
            new Ok(new $x509.BasicConstraints(false, $option.Option$None$const)),
            () => {
              return $result.try$(
                $der.parse_bool(seq_content),
                (_use0) => {
                  let ca = _use0[0];
                  let after_ca = _use0[1];
                  return $bool.guard(
                    $bit_array.byte_size(after_ca) === 0,
                    new Ok(
                      new $x509.BasicConstraints(ca, $option.Option$None$const),
                    ),
                    () => {
                      return $bool.guard(
                        !ca,
                        new Ok(
                          new $x509.BasicConstraints(
                            false,
                            $option.Option$None$const,
                          ),
                        ),
                        () => {
                          return $result.try$(
                            $der.parse_integer(after_ca),
                            (_use0) => {
                              let path_len_bytes = _use0[0];
                              let remaining$1 = _use0[1];
                              return $bool.guard(
                                !isEqual(remaining$1, toBitArray([])),
                                new Error(undefined),
                                () => {
                                  return $result.try$(
                                    bytes_to_int(path_len_bytes),
                                    (path_len) => {
                                      return new Ok(
                                        new $x509.BasicConstraints(
                                          ca,
                                          new $option.Some(path_len),
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
        },
      );
    },
  );
}

function process_extension(acc, ext) {
  let oid = ext[0];
  let is_critical = ext[1];
  let value = ext[2];
  let $ = oid.components;
  if ($ instanceof $Empty) {
    if (is_critical) {
      return new Error(new UnrecognizedCriticalExtension(oid));
    } else {
      return new Ok(acc);
    }
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      if (is_critical) {
        return new Error(new UnrecognizedCriticalExtension(oid));
      } else {
        return new Ok(acc);
      }
    } else {
      let $2 = $1.tail;
      if ($2 instanceof $Empty) {
        if (is_critical) {
          return new Error(new UnrecognizedCriticalExtension(oid));
        } else {
          return new Ok(acc);
        }
      } else {
        let $3 = $2.tail;
        if ($3 instanceof $Empty) {
          if (is_critical) {
            return new Error(new UnrecognizedCriticalExtension(oid));
          } else {
            return new Ok(acc);
          }
        } else {
          let $4 = $3.tail;
          if ($4 instanceof $Empty) {
            let $5 = $.head;
            if ($5 === 2) {
              let $6 = $1.head;
              if ($6 === 5) {
                let $7 = $2.head;
                if ($7 === 29) {
                  let $8 = $3.head;
                  if ($8 === 19) {
                    let _pipe = parse_basic_constraints_ext(value);
                    let _pipe$1 = $result.replace_error(
                      _pipe,
                      CertificateError$ParseError$const,
                    );
                    return $result.map(
                      _pipe$1,
                      (bc) => {
                        return new ExtensionsAcc(
                          new $option.Some(bc),
                          acc.key_usage,
                          acc.extended_key_usage,
                          acc.subject_alt_names,
                          acc.subject_key_identifier,
                          acc.authority_key_identifier,
                          acc.raw,
                          acc.seen_oids,
                        );
                      },
                    );
                  } else if ($8 === 15) {
                    let _pipe = parse_key_usage_ext(value);
                    let _pipe$1 = $result.replace_error(
                      _pipe,
                      CertificateError$ParseError$const,
                    );
                    return $result.map(
                      _pipe$1,
                      (key_usage) => {
                        return new ExtensionsAcc(
                          acc.basic_constraints,
                          key_usage,
                          acc.extended_key_usage,
                          acc.subject_alt_names,
                          acc.subject_key_identifier,
                          acc.authority_key_identifier,
                          acc.raw,
                          acc.seen_oids,
                        );
                      },
                    );
                  } else if ($8 === 37) {
                    let _pipe = parse_extended_key_usage_ext(value, is_critical);
                    return $result.map(
                      _pipe,
                      (extended_key_usage) => {
                        return new ExtensionsAcc(
                          acc.basic_constraints,
                          acc.key_usage,
                          extended_key_usage,
                          acc.subject_alt_names,
                          acc.subject_key_identifier,
                          acc.authority_key_identifier,
                          acc.raw,
                          acc.seen_oids,
                        );
                      },
                    );
                  } else if ($8 === 17) {
                    let _pipe = $x509_internal.parse_san_extension(
                      value,
                      is_critical,
                    );
                    let _pipe$1 = $result.replace_error(
                      _pipe,
                      CertificateError$ParseError$const,
                    );
                    return $result.map(
                      _pipe$1,
                      (subject_alt_names) => {
                        return new ExtensionsAcc(
                          acc.basic_constraints,
                          acc.key_usage,
                          acc.extended_key_usage,
                          subject_alt_names,
                          acc.subject_key_identifier,
                          acc.authority_key_identifier,
                          acc.raw,
                          acc.seen_oids,
                        );
                      },
                    );
                  } else if ($8 === 14) {
                    let _pipe = parse_subject_key_identifier_ext(value);
                    let _pipe$1 = $result.replace_error(
                      _pipe,
                      CertificateError$ParseError$const,
                    );
                    return $result.map(
                      _pipe$1,
                      (ski) => {
                        return new ExtensionsAcc(
                          acc.basic_constraints,
                          acc.key_usage,
                          acc.extended_key_usage,
                          acc.subject_alt_names,
                          new $option.Some(ski),
                          acc.authority_key_identifier,
                          acc.raw,
                          acc.seen_oids,
                        );
                      },
                    );
                  } else if ($8 === 35) {
                    let _pipe = parse_authority_key_identifier_ext(value);
                    let _pipe$1 = $result.replace_error(
                      _pipe,
                      CertificateError$ParseError$const,
                    );
                    return $result.map(
                      _pipe$1,
                      (aki) => {
                        return new ExtensionsAcc(
                          acc.basic_constraints,
                          acc.key_usage,
                          acc.extended_key_usage,
                          acc.subject_alt_names,
                          acc.subject_key_identifier,
                          new $option.Some(aki),
                          acc.raw,
                          acc.seen_oids,
                        );
                      },
                    );
                  } else {
                    if (is_critical) {
                      return new Error(new UnrecognizedCriticalExtension(oid));
                    } else {
                      return new Ok(acc);
                    }
                  }
                } else {
                  if (is_critical) {
                    return new Error(new UnrecognizedCriticalExtension(oid));
                  } else {
                    return new Ok(acc);
                  }
                }
              } else {
                if (is_critical) {
                  return new Error(new UnrecognizedCriticalExtension(oid));
                } else {
                  return new Ok(acc);
                }
              }
            } else {
              if (is_critical) {
                return new Error(new UnrecognizedCriticalExtension(oid));
              } else {
                return new Ok(acc);
              }
            }
          } else {
            if (is_critical) {
              return new Error(new UnrecognizedCriticalExtension(oid));
            } else {
              return new Ok(acc);
            }
          }
        }
      }
    }
  }
}

function parse_raw_extensions(bytes, acc) {
  if (bytes.bitSize === 0) {
    return new Ok($list.reverse(acc));
  } else {
    return $result.try$(
      $der.parse_sequence(bytes),
      (_use0) => {
        let ext_bytes = _use0[0];
        let rest = _use0[1];
        let _pipe = $x509_internal.parse_single_extension(ext_bytes);
        return $result.try$(
          _pipe,
          (ext) => { return parse_raw_extensions(rest, listPrepend(ext, acc)); },
        );
      },
    );
  }
}

function parse_extensions_content(bytes) {
  return $result.try$(
    (() => {
      let _pipe = parse_raw_extensions(bytes, $List$Empty$const);
      return $result.replace_error(_pipe, CertificateError$ParseError$const);
    })(),
    (raw) => {
      let _pipe = $list.try_fold(
        raw,
        empty_extensions_acc(),
        (acc, ext) => {
          let components;
          components = ext[0].components;
          let $ = $set.contains(acc.seen_oids, components);
          if ($) {
            return new Error(CertificateError$ParseError$const);
          } else {
            let _pipe = new ExtensionsAcc(
              acc.basic_constraints,
              acc.key_usage,
              acc.extended_key_usage,
              acc.subject_alt_names,
              acc.subject_key_identifier,
              acc.authority_key_identifier,
              acc.raw,
              $set.insert(acc.seen_oids, components),
            );
            return process_extension(_pipe, ext);
          }
        },
      );
      return $result.map(
        _pipe,
        (acc) => {
          return new ExtensionsAcc(
            acc.basic_constraints,
            acc.key_usage,
            acc.extended_key_usage,
            acc.subject_alt_names,
            acc.subject_key_identifier,
            acc.authority_key_identifier,
            raw,
            acc.seen_oids,
          );
        },
      );
    },
  );
}

/**
 * Parse optional unique IDs with RFC 5280 version validation.
 * 
 * @ignore
 */
function parse_optional_unique_ids(bytes, version) {
  if (bytes.bitSize >= 8) {
    if (bytes.byteAt(0) === 129) {
      return $bool.guard(
        version < 1,
        new Error(CertificateError$ParseError$const),
        () => {
          let $ = $der.parse_tlv(bytes);
          if ($ instanceof Ok) {
            let remaining = $[0][2];
            return parse_optional_unique_ids(remaining, version);
          } else {
            return new Error(CertificateError$ParseError$const);
          }
        },
      );
    } else if (bytes.byteAt(0) === 130) {
      return $bool.guard(
        version < 1,
        new Error(CertificateError$ParseError$const),
        () => {
          let $ = $der.parse_tlv(bytes);
          if ($ instanceof Ok) {
            let remaining = $[0][2];
            return parse_optional_unique_ids(remaining, version);
          } else {
            return new Error(CertificateError$ParseError$const);
          }
        },
      );
    } else {
      return new Ok(bytes);
    }
  } else {
    return new Ok(bytes);
  }
}

/**
 * Parse extensions with RFC 5280 version validation.
 * 
 * @ignore
 */
function parse_certificate_extensions(bytes, version) {
  return $result.try$(
    parse_optional_unique_ids(bytes, version),
    (bytes) => {
      let $ = $der.parse_context_tag(bytes, 3);
      if ($ instanceof Ok) {
        let exts_content = $[0][0];
        return $bool.guard(
          version < 2,
          new Error(CertificateError$ParseError$const),
          () => {
            return $result.try$(
              (() => {
                let _pipe = $der.parse_sequence(exts_content);
                return $result.replace_error(
                  _pipe,
                  CertificateError$ParseError$const,
                );
              })(),
              (_use0) => {
                let exts_seq = _use0[0];
                return parse_extensions_content(exts_seq);
              },
            );
          },
        );
      } else {
        return new Ok(empty_extensions_acc());
      }
    },
  );
}

function parse_time(bytes) {
  if (bytes.bitSize >= 8) {
    if (bytes.byteAt(0) === 23) {
      return $der.parse_utc_time(bytes);
    } else if (bytes.byteAt(0) === 24) {
      return $der.parse_generalized_time(bytes);
    } else {
      return new Error(undefined);
    }
  } else {
    return new Error(undefined);
  }
}

function parse_validity(bytes) {
  return $result.try$(
    (() => {
      let _pipe = parse_time(bytes);
      return $result.replace_error(_pipe, CertificateError$ParseError$const);
    })(),
    (_use0) => {
      let not_before = _use0[0];
      let after_not_before = _use0[1];
      return $result.try$(
        (() => {
          let _pipe = parse_time(after_not_before);
          return $result.replace_error(_pipe, CertificateError$ParseError$const);
        })(),
        (_use0) => {
          let not_after = _use0[0];
          return new Ok(new $x509.Validity(not_before, not_after));
        },
      );
    },
  );
}

function parse_certificate_version(bytes) {
  let $ = $der.parse_context_tag(bytes, 0);
  if ($ instanceof Ok) {
    let version_content = $[0][0];
    let rest = $[0][1];
    return $result.try$(
      (() => {
        let _pipe = $der.parse_integer(version_content);
        return $result.replace_error(_pipe, CertificateError$ParseError$const);
      })(),
      (_use0) => {
        let version_bytes = _use0[0];
        if (version_bytes.bitSize === 8) {
          if (version_bytes.byteAt(0) === 0) {
            return new Ok([0, rest]);
          } else if (version_bytes.byteAt(0) === 1) {
            return new Ok([1, rest]);
          } else if (version_bytes.byteAt(0) === 2) {
            return new Ok([2, rest]);
          } else {
            return new Error(CertificateError$ParseError$const);
          }
        } else {
          return new Error(CertificateError$ParseError$const);
        }
      },
    );
  } else {
    return new Ok([0, bytes]);
  }
}

/**
 * Parse a DER-encoded X.509 certificate.
 *
 * Validates the ASN.1 structure and extracts all standard fields and
 * extensions. Unknown non-critical extensions are preserved but not parsed.
 *
 * **Note:** This function does NOT verify the certificate's cryptographic
 * signature. To verify a certificate was signed by an issuer, use `verify()`.
 * For self-signed certificates, use `verify_self_signed()`.
 */
export function from_der(der) {
  return $result.try$(
    (() => {
      let _pipe = $der.parse_sequence(der);
      return $result.replace_error(_pipe, CertificateError$ParseError$const);
    })(),
    (_use0) => {
      let cert_content = _use0[0];
      let remaining = _use0[1];
      return $bool.guard(
        $bit_array.byte_size(remaining) !== 0,
        new Error(CertificateError$ParseError$const),
        () => {
          return $result.try$(
            (() => {
              let _pipe = $x509_internal.parse_sequence_with_header(
                cert_content,
              );
              return $result.replace_error(
                _pipe,
                CertificateError$ParseError$const,
              );
            })(),
            (_use0) => {
              let tbs_bytes = _use0[0];
              let after_tbs = _use0[1];
              return $result.try$(
                (() => {
                  let _pipe = $der.parse_sequence(tbs_bytes);
                  return $result.replace_error(
                    _pipe,
                    CertificateError$ParseError$const,
                  );
                })(),
                (_use0) => {
                  let tbs_content = _use0[0];
                  return $result.try$(
                    parse_certificate_version(tbs_content),
                    (_use0) => {
                      let version$1 = _use0[0];
                      let after_version = _use0[1];
                      return $result.try$(
                        (() => {
                          let _pipe = $der.parse_integer(after_version);
                          return $result.replace_error(
                            _pipe,
                            CertificateError$ParseError$const,
                          );
                        })(),
                        (_use0) => {
                          let serial_number$1 = _use0[0];
                          let after_serial = _use0[1];
                          return $result.try$(
                            (() => {
                              let _pipe = $der.parse_sequence(after_serial);
                              return $result.replace_error(
                                _pipe,
                                CertificateError$ParseError$const,
                              );
                            })(),
                            (_use0) => {
                              let sig_alg_bytes = _use0[0];
                              let after_sig_alg = _use0[1];
                              return $result.try$(
                                (() => {
                                  let _pipe = $x509_internal.parse_signature_algorithm(
                                    sig_alg_bytes,
                                  );
                                  return $result.map_error(
                                    _pipe,
                                    (var0) => {
                                      return new UnsupportedAlgorithm(var0);
                                    },
                                  );
                                })(),
                                (signature_algorithm) => {
                                  return $result.try$(
                                    (() => {
                                      let _pipe = $der.parse_sequence(
                                        after_sig_alg,
                                      );
                                      return $result.replace_error(
                                        _pipe,
                                        CertificateError$ParseError$const,
                                      );
                                    })(),
                                    (_use0) => {
                                      let issuer_bytes = _use0[0];
                                      let after_issuer = _use0[1];
                                      return $result.try$(
                                        (() => {
                                          let _pipe = $x509_internal.parse_name(
                                            issuer_bytes,
                                          );
                                          return $result.replace_error(
                                            _pipe,
                                            CertificateError$ParseError$const,
                                          );
                                        })(),
                                        (issuer) => {
                                          return $result.try$(
                                            (() => {
                                              let _pipe = $der.parse_sequence(
                                                after_issuer,
                                              );
                                              return $result.replace_error(
                                                _pipe,
                                                CertificateError$ParseError$const,
                                              );
                                            })(),
                                            (_use0) => {
                                              let validity_bytes = _use0[0];
                                              let after_validity = _use0[1];
                                              return $result.try$(
                                                parse_validity(validity_bytes),
                                                (validity) => {
                                                  return $result.try$(
                                                    (() => {
                                                      let _pipe = $der.parse_sequence(
                                                        after_validity,
                                                      );
                                                      return $result.replace_error(
                                                        _pipe,
                                                        CertificateError$ParseError$const,
                                                      );
                                                    })(),
                                                    (_use0) => {
                                                      let subject_bytes = _use0[0];
                                                      let after_subject = _use0[1];
                                                      return $result.try$(
                                                        (() => {
                                                          let _pipe = $x509_internal.parse_name(
                                                            subject_bytes,
                                                          );
                                                          return $result.replace_error(
                                                            _pipe,
                                                            CertificateError$ParseError$const,
                                                          );
                                                        })(),
                                                        (subject) => {
                                                          return $result.try$(
                                                            (() => {
                                                              let _pipe = $x509_internal.parse_sequence_with_header(
                                                                after_subject,
                                                              );
                                                              return $result.replace_error(
                                                                _pipe,
                                                                CertificateError$ParseError$const,
                                                              );
                                                            })(),
                                                            (_use0) => {
                                                              let spki_bytes = _use0[0];
                                                              let after_spki = _use0[1];
                                                              return $result.try$(
                                                                (() => {
                                                                  let _pipe = $x509_internal.parse_public_key(
                                                                    spki_bytes,
                                                                  );
                                                                  return $result.map_error(
                                                                    _pipe,
                                                                    (oid) => {
                                                                      let $ = oid.components;
                                                                      if (
                                                                        $ instanceof $Empty
                                                                      ) {
                                                                        return CertificateError$ParseError$const;
                                                                      } else {
                                                                        return new UnsupportedAlgorithm(
                                                                          oid,
                                                                        );
                                                                      }
                                                                    },
                                                                  );
                                                                })(),
                                                                (public_key) => {
                                                                  return $result.try$(
                                                                    parse_certificate_extensions(
                                                                      after_spki,
                                                                      version$1,
                                                                    ),
                                                                    (exts) => {
                                                                      return $result.try$(
                                                                        (() => {
                                                                          let _pipe = $der.parse_sequence(
                                                                            after_tbs,
                                                                          );
                                                                          return $result.replace_error(
                                                                            _pipe,
                                                                            CertificateError$ParseError$const,
                                                                          );
                                                                        })(),
                                                                        (_use0) => {
                                                                          let outer_sig_alg_bytes = _use0[0];
                                                                          let after_outer_sig_alg = _use0[1];
                                                                          return $result.try$(
                                                                            (() => {
                                                                              let _pipe = $x509_internal.parse_signature_algorithm(
                                                                                outer_sig_alg_bytes,
                                                                              );
                                                                              return $result.replace_error(
                                                                                _pipe,
                                                                                CertificateError$ParseError$const,
                                                                              );
                                                                            })(),
                                                                            (
                                                                                outer_signature_algorithm
                                                                              ) => {
                                                                              return $bool.guard(
                                                                                !isEqual(
                                                                                  signature_algorithm,
                                                                                  outer_signature_algorithm
                                                                                ),
                                                                                new Error(
                                                                                  CertificateError$ParseError$const,
                                                                                ),
                                                                                (
                                                                                    
                                                                                  ) => {
                                                                                  return $result.try$(
                                                                                    (() => {
                                                                                      let _pipe = $der.parse_bit_string(
                                                                                        after_outer_sig_alg,
                                                                                      );
                                                                                      return $result.replace_error(
                                                                                        _pipe,
                                                                                        CertificateError$ParseError$const,
                                                                                      );
                                                                                    })(),
                                                                                    (
                                                                                        _use0
                                                                                      ) => {
                                                                                      let signature = _use0[0];
                                                                                      return new Ok(
                                                                                        new ParsedCertificate(
                                                                                          der,
                                                                                          tbs_bytes,
                                                                                          signature,
                                                                                          version$1,
                                                                                          serial_number$1,
                                                                                          signature_algorithm,
                                                                                          issuer,
                                                                                          validity,
                                                                                          subject,
                                                                                          public_key,
                                                                                          exts.basic_constraints,
                                                                                          exts.key_usage,
                                                                                          exts.extended_key_usage,
                                                                                          exts.subject_alt_names,
                                                                                          exts.subject_key_identifier,
                                                                                          exts.authority_key_identifier,
                                                                                          exts.raw,
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
 * Parse all PEM-encoded certificates from a string.
 *
 * Extracts and parses all `-----BEGIN CERTIFICATE-----` blocks from the input.
 * Certificates are returned in the order they appear.
 *
 * **Note:** This function does NOT verify the certificates' cryptographic
 * signatures. To verify a certificate was signed by an issuer, use `verify()`.
 * For self-signed certificates, use `verify_self_signed()`.
 */
export function from_pem(pem) {
  let _pipe = $x509_internal.decode_pem_all(pem, pem_begin, pem_end);
  let _pipe$1 = $result.replace_error(_pipe, CertificateError$ParseError$const);
  return $result.try$(
    _pipe$1,
    (_capture) => { return $list.try_map(_capture, from_der); },
  );
}

/**
 * Returns the version of a parsed certificate (0 = v1, 1 = v2, 2 = v3).
 */
export function version(cert) {
  let version$1;
  if (cert instanceof ParsedCertificate) {
    version$1 = cert.version;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      640,
      "version",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 20268,
        end: 20317,
        pattern_start: 20279,
        pattern_end: 20310
      }
    )
  }
  return version$1;
}

/**
 * Returns the serial number of a parsed certificate.
 */
export function serial_number(cert) {
  let serial_number$1;
  if (cert instanceof ParsedCertificate) {
    serial_number$1 = cert.serial_number;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      646,
      "serial_number",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 20450,
        end: 20505,
        pattern_start: 20461,
        pattern_end: 20498
      }
    )
  }
  return serial_number$1;
}

/**
 * Returns the signature algorithm used to sign the certificate.
 */
export function signature_algorithm(cert) {
  let signature_algorithm$1;
  if (cert instanceof ParsedCertificate) {
    signature_algorithm$1 = cert.signature_algorithm;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      652,
      "signature_algorithm",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 20676,
        end: 20737,
        pattern_start: 20687,
        pattern_end: 20730
      }
    )
  }
  return signature_algorithm$1;
}

/**
 * Returns the issuer distinguished name.
 *
 * For self-signed certificates, issuer equals subject.
 */
export function issuer(cert) {
  let issuer$1;
  if (cert instanceof ParsedCertificate) {
    issuer$1 = cert.issuer;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      660,
      "issuer",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 20925,
        end: 20973,
        pattern_start: 20936,
        pattern_end: 20966
      }
    )
  }
  return issuer$1;
}

/**
 * Returns the validity period of the certificate.
 */
export function validity(cert) {
  let validity$1;
  if (cert instanceof ParsedCertificate) {
    validity$1 = cert.validity;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      666,
      "validity",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 21102,
        end: 21152,
        pattern_start: 21113,
        pattern_end: 21145
      }
    )
  }
  return validity$1;
}

/**
 * Returns the subject distinguished name.
 */
export function subject(cert) {
  let subject$1;
  if (cert instanceof ParsedCertificate) {
    subject$1 = cert.subject;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      672,
      "subject",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 21270,
        end: 21319,
        pattern_start: 21281,
        pattern_end: 21312
      }
    )
  }
  return subject$1;
}

/**
 * Returns the public key embedded in the certificate.
 */
export function public_key(cert) {
  let public_key$1;
  if (cert instanceof ParsedCertificate) {
    public_key$1 = cert.public_key;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      678,
      "public_key",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 21456,
        end: 21508,
        pattern_start: 21467,
        pattern_end: 21501
      }
    )
  }
  return public_key$1;
}

/**
 * Returns the Basic Constraints extension from a parsed certificate.
 */
export function basic_constraints(cert) {
  let basic_constraints$1;
  if (cert instanceof ParsedCertificate) {
    basic_constraints$1 = cert.basic_constraints;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      686,
      "basic_constraints",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 21695,
        end: 21754,
        pattern_start: 21706,
        pattern_end: 21747
      }
    )
  }
  return $option.to_result(basic_constraints$1, undefined);
}

/**
 * Returns the Key Usage flags from a parsed certificate.
 */
export function key_usage(cert) {
  let key_usage$1;
  if (cert instanceof ParsedCertificate) {
    key_usage$1 = cert.key_usage;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      692,
      "key_usage",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 21931,
        end: 21982,
        pattern_start: 21942,
        pattern_end: 21975
      }
    )
  }
  return key_usage$1;
}

/**
 * Returns the Extended Key Usage purposes from a parsed certificate.
 */
export function extended_key_usage(cert) {
  let extended_key_usage$1;
  if (cert instanceof ParsedCertificate) {
    extended_key_usage$1 = cert.extended_key_usage;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      700,
      "extended_key_usage",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 22162,
        end: 22222,
        pattern_start: 22173,
        pattern_end: 22215
      }
    )
  }
  return extended_key_usage$1;
}

/**
 * Returns the Subject Alternative Names (SANs) from a parsed certificate.
 */
export function subject_alt_names(cert) {
  let subject_alt_names$1;
  if (cert instanceof ParsedCertificate) {
    subject_alt_names$1 = cert.subject_alt_names;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      706,
      "subject_alt_names",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 22408,
        end: 22467,
        pattern_start: 22419,
        pattern_end: 22460
      }
    )
  }
  return subject_alt_names$1;
}

/**
 * Returns the Subject Key Identifier (SKI) from a parsed certificate.
 */
export function subject_key_identifier(cert) {
  let subject_key_identifier$1;
  if (cert instanceof ParsedCertificate) {
    subject_key_identifier$1 = cert.subject_key_identifier;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      714,
      "subject_key_identifier",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 22654,
        end: 22718,
        pattern_start: 22665,
        pattern_end: 22711
      }
    )
  }
  return $option.to_result(subject_key_identifier$1, undefined);
}

/**
 * Returns the Authority Key Identifier (AKI) from a parsed certificate.
 */
export function authority_key_identifier(cert) {
  let authority_key_identifier$1;
  if (cert instanceof ParsedCertificate) {
    authority_key_identifier$1 = cert.authority_key_identifier;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      722,
      "authority_key_identifier",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 22956,
        end: 23022,
        pattern_start: 22967,
        pattern_end: 23015
      }
    )
  }
  return $option.to_result(authority_key_identifier$1, undefined);
}

/**
 * Returns all extensions as raw (OID, critical, value) tuples.
 *
 * Includes all extensions, even those with typed representations.
 * The Bool indicates whether the extension was marked as critical per RFC 5280.
 */
export function extensions(cert) {
  let extensions$1;
  if (cert instanceof ParsedCertificate) {
    extensions$1 = cert.extensions;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      733,
      "extensions",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 23386,
        end: 23438,
        pattern_start: 23397,
        pattern_end: 23431
      }
    )
  }
  return extensions$1;
}

function xdh_key_oid(key) {
  if (key instanceof $x509.XdhPublicKey) {
    let xdh_key = key[0];
    let $ = $xdh.public_key_curve(xdh_key);
    if ($ instanceof $xdh.X25519) {
      return new Ok(new $x509.Oid(toList([1, 3, 101, 110])));
    } else {
      return new Ok(new $x509.Oid(toList([1, 3, 101, 111])));
    }
  } else {
    return new Error(undefined);
  }
}

function is_xdh_key(key) {
  if (key instanceof $x509.XdhPublicKey) {
    return true;
  } else {
    return false;
  }
}

/**
 * Verify a certificate's signature against an issuer's public key.
 *
 * The public key must be RSA, ECDSA, or EdDSA (XDH keys cannot sign).
 */
export function verify(cert, issuer_public_key) {
  let tbs_bytes;
  let signature;
  let signature_algorithm$1;
  if (cert instanceof ParsedCertificate) {
    tbs_bytes = cert.tbs_bytes;
    signature = cert.signature;
    signature_algorithm$1 = cert.signature_algorithm;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/x509/certificate",
      744,
      "verify",
      "Pattern match failed, no pattern matched the value.",
      {
        value: cert,
        start: 23720,
        end: 23809,
        pattern_start: 23731,
        pattern_end: 23798
      }
    )
  }
  return $bool.lazy_guard(
    is_xdh_key(issuer_public_key),
    () => {
      let _block;
      let _pipe = xdh_key_oid(issuer_public_key);
      _block = $result.unwrap(_pipe, new $x509.Oid($List$Empty$const));
      let oid = _block;
      return new Error(new UnsupportedAlgorithm(oid));
    },
    () => {
      let verified = $x509_internal.verify_signature(
        issuer_public_key,
        tbs_bytes,
        signature,
        signature_algorithm$1,
      );
      if (verified) {
        return new Ok(undefined);
      } else {
        return new Error(CertificateError$SignatureVerificationFailed$const);
      }
    },
  );
}

/**
 * Verify a self-signed certificate against its own public key.
 */
export function verify_self_signed(cert) {
  let _pipe = public_key(cert);
  return ((_capture) => { return verify(cert, _capture); })(_pipe);
}
