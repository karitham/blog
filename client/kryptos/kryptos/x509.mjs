import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import * as $timestamp from "../../gleam_time/gleam/time/timestamp.mjs";
import { toList, Empty as $Empty, CustomType as $CustomType } from "../gleam.mjs";
import * as $ec from "../kryptos/ec.mjs";
import * as $eddsa from "../kryptos/eddsa.mjs";
import * as $der from "../kryptos/internal/der.mjs";
import * as $rsa from "../kryptos/rsa.mjs";
import * as $xdh from "../kryptos/xdh.mjs";

export class Oid extends $CustomType {
  constructor(components) {
    super();
    this.components = components;
  }
}
export const Oid$Oid = (components) => new Oid(components);
export const Oid$isOid = (value) => value instanceof Oid;
export const Oid$Oid$components = (value) => value.components;
export const Oid$Oid$0 = (value) => value.components;

export class Name extends $CustomType {
  constructor(rdns) {
    super();
    this.rdns = rdns;
  }
}
export const Name$Name = (rdns) => new Name(rdns);
export const Name$isName = (value) => value instanceof Name;
export const Name$Name$rdns = (value) => value.rdns;
export const Name$Name$0 = (value) => value.rdns;

export class Rdn extends $CustomType {
  constructor(attributes) {
    super();
    this.attributes = attributes;
  }
}
export const Rdn$Rdn = (attributes) => new Rdn(attributes);
export const Rdn$isRdn = (value) => value instanceof Rdn;
export const Rdn$Rdn$attributes = (value) => value.attributes;
export const Rdn$Rdn$0 = (value) => value.attributes;

class Utf8String extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}

class PrintableString extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}

class Ia5String extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}

/**
 * A DNS hostname (e.g., "example.com").
 */
export class DnsName extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const SubjectAltName$DnsName = ($0) => new DnsName($0);
export const SubjectAltName$isDnsName = (value) => value instanceof DnsName;
export const SubjectAltName$DnsName$0 = (value) => value[0];

/**
 * An IP address (4 bytes for IPv4, 16 bytes for IPv6).
 */
export class IpAddress extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const SubjectAltName$IpAddress = ($0) => new IpAddress($0);
export const SubjectAltName$isIpAddress = (value) => value instanceof IpAddress;
export const SubjectAltName$IpAddress$0 = (value) => value[0];

/**
 * An email address (e.g., "user@example.com").
 */
export class Email extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const SubjectAltName$Email = ($0) => new Email($0);
export const SubjectAltName$isEmail = (value) => value instanceof Email;
export const SubjectAltName$Email$0 = (value) => value[0];

/**
 * A Uniform Resource Identifier (e.g., "https://example.com/path").
 */
export class Uri extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const SubjectAltName$Uri = ($0) => new Uri($0);
export const SubjectAltName$isUri = (value) => value instanceof Uri;
export const SubjectAltName$Uri$0 = (value) => value[0];

/**
 * A distinguished name, used when a certificate identifies a directory entity.
 */
export class DirectoryName extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const SubjectAltName$DirectoryName = ($0) => new DirectoryName($0);
export const SubjectAltName$isDirectoryName = (value) =>
  value instanceof DirectoryName;
export const SubjectAltName$DirectoryName$0 = (value) => value[0];

/**
 * A registered OID identifying a name form (e.g., for hardware modules).
 */
export class RegisteredId extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const SubjectAltName$RegisteredId = ($0) => new RegisteredId($0);
export const SubjectAltName$isRegisteredId = (value) =>
  value instanceof RegisteredId;
export const SubjectAltName$RegisteredId$0 = (value) => value[0];

/**
 * An application-specific name form with an OID type and raw value.
 */
export class OtherName extends $CustomType {
  constructor(oid, value) {
    super();
    this.oid = oid;
    this.value = value;
  }
}
export const SubjectAltName$OtherName = (oid, value) =>
  new OtherName(oid, value);
export const SubjectAltName$isOtherName = (value) => value instanceof OtherName;
export const SubjectAltName$OtherName$oid = (value) => value.oid;
export const SubjectAltName$OtherName$0 = (value) => value.oid;
export const SubjectAltName$OtherName$value = (value) => value.value;
export const SubjectAltName$OtherName$1 = (value) => value.value;

/**
 * An unknown GeneralName type with its raw tag byte and value.
 * Returned when parsing encounters an unrecognized SAN type.
 */
export class Unknown extends $CustomType {
  constructor(tag, value) {
    super();
    this.tag = tag;
    this.value = value;
  }
}
export const SubjectAltName$Unknown = (tag, value) => new Unknown(tag, value);
export const SubjectAltName$isUnknown = (value) => value instanceof Unknown;
export const SubjectAltName$Unknown$tag = (value) => value.tag;
export const SubjectAltName$Unknown$0 = (value) => value.tag;
export const SubjectAltName$Unknown$value = (value) => value.value;
export const SubjectAltName$Unknown$1 = (value) => value.value;

export class Extensions extends $CustomType {
  constructor(subject_alt_names) {
    super();
    this.subject_alt_names = subject_alt_names;
  }
}
export const Extensions$Extensions = (subject_alt_names) =>
  new Extensions(subject_alt_names);
export const Extensions$isExtensions = (value) => value instanceof Extensions;
export const Extensions$Extensions$subject_alt_names = (value) =>
  value.subject_alt_names;
export const Extensions$Extensions$0 = (value) => value.subject_alt_names;

/**
 * An elliptic-curve public key (e.g., P-256, P-384).
 */
export class EcPublicKey extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const PublicKey$EcPublicKey = ($0) => new EcPublicKey($0);
export const PublicKey$isEcPublicKey = (value) => value instanceof EcPublicKey;
export const PublicKey$EcPublicKey$0 = (value) => value[0];

/**
 * An RSA public key.
 */
export class RsaPublicKey extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const PublicKey$RsaPublicKey = ($0) => new RsaPublicKey($0);
export const PublicKey$isRsaPublicKey = (value) =>
  value instanceof RsaPublicKey;
export const PublicKey$RsaPublicKey$0 = (value) => value[0];

/**
 * An EdDSA public key (Ed25519 or Ed448).
 */
export class EdPublicKey extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const PublicKey$EdPublicKey = ($0) => new EdPublicKey($0);
export const PublicKey$isEdPublicKey = (value) => value instanceof EdPublicKey;
export const PublicKey$EdPublicKey$0 = (value) => value[0];

/**
 * An XDH public key (e.g., Curve25519 or Curve448).
 */
export class XdhPublicKey extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const PublicKey$XdhPublicKey = ($0) => new XdhPublicKey($0);
export const PublicKey$isXdhPublicKey = (value) =>
  value instanceof XdhPublicKey;
export const PublicKey$XdhPublicKey$0 = (value) => value[0];

/**
 * RSA with SHA-1, suitable for legacy systems.
 */
export class RsaSha1 extends $CustomType {}
export const SignatureAlgorithm$RsaSha1 = () => new RsaSha1();
export const SignatureAlgorithm$isRsaSha1 = (value) => value instanceof RsaSha1;

/**
 * RSA with SHA-256
 */
export class RsaSha256 extends $CustomType {}
export const SignatureAlgorithm$RsaSha256 = () => new RsaSha256();
export const SignatureAlgorithm$isRsaSha256 = (value) =>
  value instanceof RsaSha256;

/**
 * RSA with SHA-384
 */
export class RsaSha384 extends $CustomType {}
export const SignatureAlgorithm$RsaSha384 = () => new RsaSha384();
export const SignatureAlgorithm$isRsaSha384 = (value) =>
  value instanceof RsaSha384;

/**
 * RSA with SHA-512
 */
export class RsaSha512 extends $CustomType {}
export const SignatureAlgorithm$RsaSha512 = () => new RsaSha512();
export const SignatureAlgorithm$isRsaSha512 = (value) =>
  value instanceof RsaSha512;

/**
 * ECDSA with SHA-1, for legacy elliptic curve systems.
 */
export class EcdsaSha1 extends $CustomType {}
export const SignatureAlgorithm$EcdsaSha1 = () => new EcdsaSha1();
export const SignatureAlgorithm$isEcdsaSha1 = (value) =>
  value instanceof EcdsaSha1;

/**
 * ECDSA with SHA-256
 */
export class EcdsaSha256 extends $CustomType {}
export const SignatureAlgorithm$EcdsaSha256 = () => new EcdsaSha256();
export const SignatureAlgorithm$isEcdsaSha256 = (value) =>
  value instanceof EcdsaSha256;

/**
 * ECDSA with SHA-384
 */
export class EcdsaSha384 extends $CustomType {}
export const SignatureAlgorithm$EcdsaSha384 = () => new EcdsaSha384();
export const SignatureAlgorithm$isEcdsaSha384 = (value) =>
  value instanceof EcdsaSha384;

/**
 * ECDSA with SHA-512
 */
export class EcdsaSha512 extends $CustomType {}
export const SignatureAlgorithm$EcdsaSha512 = () => new EcdsaSha512();
export const SignatureAlgorithm$isEcdsaSha512 = (value) =>
  value instanceof EcdsaSha512;

/**
 * Edwards-Curve Digital Signature Algorithm using Ed25519
 */
export class Ed25519 extends $CustomType {}
export const SignatureAlgorithm$Ed25519 = () => new Ed25519();
export const SignatureAlgorithm$isEd25519 = (value) => value instanceof Ed25519;

/**
 * Edwards-Curve Digital Signature Algorithm using Ed448
 */
export class Ed448 extends $CustomType {}
export const SignatureAlgorithm$Ed448 = () => new Ed448();
export const SignatureAlgorithm$isEd448 = (value) => value instanceof Ed448;

export class BasicConstraints extends $CustomType {
  constructor(ca, path_len_constraint) {
    super();
    this.ca = ca;
    this.path_len_constraint = path_len_constraint;
  }
}
export const BasicConstraints$BasicConstraints = (ca, path_len_constraint) =>
  new BasicConstraints(ca, path_len_constraint);
export const BasicConstraints$isBasicConstraints = (value) =>
  value instanceof BasicConstraints;
export const BasicConstraints$BasicConstraints$ca = (value) => value.ca;
export const BasicConstraints$BasicConstraints$0 = (value) => value.ca;
export const BasicConstraints$BasicConstraints$path_len_constraint = (value) =>
  value.path_len_constraint;
export const BasicConstraints$BasicConstraints$1 = (value) =>
  value.path_len_constraint;

/**
 * Verify digital signatures (other than certificates and CRLs).
 */
export class DigitalSignature extends $CustomType {}
export const KeyUsage$DigitalSignature = () => new DigitalSignature();
export const KeyUsage$isDigitalSignature = (value) =>
  value instanceof DigitalSignature;

/**
 * Verify signatures for non-repudiation services (also called contentCommitment).
 */
export class NonRepudiation extends $CustomType {}
export const KeyUsage$NonRepudiation = () => new NonRepudiation();
export const KeyUsage$isNonRepudiation = (value) =>
  value instanceof NonRepudiation;

/**
 * Encipher private or secret keys (e.g., RSA key transport).
 */
export class KeyEncipherment extends $CustomType {}
export const KeyUsage$KeyEncipherment = () => new KeyEncipherment();
export const KeyUsage$isKeyEncipherment = (value) =>
  value instanceof KeyEncipherment;

/**
 * Directly encrypt raw user data (without key agreement).
 */
export class DataEncipherment extends $CustomType {}
export const KeyUsage$DataEncipherment = () => new DataEncipherment();
export const KeyUsage$isDataEncipherment = (value) =>
  value instanceof DataEncipherment;

/**
 * Key agreement protocols (e.g., Diffie-Hellman).
 */
export class KeyAgreement extends $CustomType {}
export const KeyUsage$KeyAgreement = () => new KeyAgreement();
export const KeyUsage$isKeyAgreement = (value) => value instanceof KeyAgreement;

/**
 * Verify signatures on public key certificates (CA certificates).
 */
export class KeyCertSign extends $CustomType {}
export const KeyUsage$KeyCertSign = () => new KeyCertSign();
export const KeyUsage$isKeyCertSign = (value) => value instanceof KeyCertSign;

/**
 * Verify signatures on certificate revocation lists.
 */
export class CrlSign extends $CustomType {}
export const KeyUsage$CrlSign = () => new CrlSign();
export const KeyUsage$isCrlSign = (value) => value instanceof CrlSign;

/**
 * With KeyAgreement, may only encipher data during key agreement.
 */
export class EncipherOnly extends $CustomType {}
export const KeyUsage$EncipherOnly = () => new EncipherOnly();
export const KeyUsage$isEncipherOnly = (value) => value instanceof EncipherOnly;

/**
 * With KeyAgreement, may only decipher data during key agreement.
 */
export class DecipherOnly extends $CustomType {}
export const KeyUsage$DecipherOnly = () => new DecipherOnly();
export const KeyUsage$isDecipherOnly = (value) => value instanceof DecipherOnly;

/**
 * TLS server authentication.
 */
export class ServerAuth extends $CustomType {}
export const ExtendedKeyUsage$ServerAuth = () => new ServerAuth();
export const ExtendedKeyUsage$isServerAuth = (value) =>
  value instanceof ServerAuth;

/**
 * TLS client authentication.
 */
export class ClientAuth extends $CustomType {}
export const ExtendedKeyUsage$ClientAuth = () => new ClientAuth();
export const ExtendedKeyUsage$isClientAuth = (value) =>
  value instanceof ClientAuth;

/**
 * Signing downloadable executable code.
 */
export class CodeSigning extends $CustomType {}
export const ExtendedKeyUsage$CodeSigning = () => new CodeSigning();
export const ExtendedKeyUsage$isCodeSigning = (value) =>
  value instanceof CodeSigning;

/**
 * Email protection (S/MIME signing and encryption).
 */
export class EmailProtection extends $CustomType {}
export const ExtendedKeyUsage$EmailProtection = () => new EmailProtection();
export const ExtendedKeyUsage$isEmailProtection = (value) =>
  value instanceof EmailProtection;

/**
 * Signing OCSP responses.
 */
export class OcspSigning extends $CustomType {}
export const ExtendedKeyUsage$OcspSigning = () => new OcspSigning();
export const ExtendedKeyUsage$isOcspSigning = (value) =>
  value instanceof OcspSigning;

export class Validity extends $CustomType {
  constructor(not_before, not_after) {
    super();
    this.not_before = not_before;
    this.not_after = not_after;
  }
}
export const Validity$Validity = (not_before, not_after) =>
  new Validity(not_before, not_after);
export const Validity$isValidity = (value) => value instanceof Validity;
export const Validity$Validity$not_before = (value) => value.not_before;
export const Validity$Validity$0 = (value) => value.not_before;
export const Validity$Validity$not_after = (value) => value.not_after;
export const Validity$Validity$1 = (value) => value.not_after;

export class AuthorityKeyIdentifier extends $CustomType {
  constructor(key_identifier, authority_cert_issuer, authority_cert_serial_number) {
    super();
    this.key_identifier = key_identifier;
    this.authority_cert_issuer = authority_cert_issuer;
    this.authority_cert_serial_number = authority_cert_serial_number;
  }
}
export const AuthorityKeyIdentifier$AuthorityKeyIdentifier = (key_identifier, authority_cert_issuer, authority_cert_serial_number) =>
  new AuthorityKeyIdentifier(key_identifier,
  authority_cert_issuer,
  authority_cert_serial_number);
export const AuthorityKeyIdentifier$isAuthorityKeyIdentifier = (value) =>
  value instanceof AuthorityKeyIdentifier;
export const AuthorityKeyIdentifier$AuthorityKeyIdentifier$key_identifier = (value) =>
  value.key_identifier;
export const AuthorityKeyIdentifier$AuthorityKeyIdentifier$0 = (value) =>
  value.key_identifier;
export const AuthorityKeyIdentifier$AuthorityKeyIdentifier$authority_cert_issuer = (value) =>
  value.authority_cert_issuer;
export const AuthorityKeyIdentifier$AuthorityKeyIdentifier$1 = (value) =>
  value.authority_cert_issuer;
export const AuthorityKeyIdentifier$AuthorityKeyIdentifier$authority_cert_serial_number = (value) =>
  value.authority_cert_serial_number;
export const AuthorityKeyIdentifier$AuthorityKeyIdentifier$2 = (value) =>
  value.authority_cert_serial_number;

const oid_common_name = /* @__PURE__ */ new Oid(
  /* @__PURE__ */ toList([2, 5, 4, 3]),
);

const oid_organization = /* @__PURE__ */ new Oid(
  /* @__PURE__ */ toList([2, 5, 4, 10]),
);

const oid_organizational_unit = /* @__PURE__ */ new Oid(
  /* @__PURE__ */ toList([2, 5, 4, 11]),
);

const oid_country = /* @__PURE__ */ new Oid(
  /* @__PURE__ */ toList([2, 5, 4, 6]),
);

const oid_state = /* @__PURE__ */ new Oid(/* @__PURE__ */ toList([2, 5, 4, 8]));

const oid_locality = /* @__PURE__ */ new Oid(
  /* @__PURE__ */ toList([2, 5, 4, 7]),
);

const oid_email_address = /* @__PURE__ */ new Oid(
  /* @__PURE__ */ toList([1, 2, 840, 113_549, 1, 9, 1]),
);

/**
 * Builds a distinguished name from a list of attribute-value pairs.
 *
 * Creates a Name with each attribute in its own Relative Distinguished Name
 * (RDN). Use helper functions like `cn`, `organization`, `country`, etc.
 * to construct the attribute list.
 */
export function name(attributes) {
  return new Name(
    $list.map(attributes, (attr) => { return new Rdn(toList([attr])); }),
  );
}

/**
 * Creates a Common Name (CN) attribute.
 *
 * The Common Name typically contains the primary identifier for the subject,
 * such as a domain name for server certificates or a person's name for
 * client certificates.
 */
export function cn(value) {
  return [oid_common_name, new Utf8String(value)];
}

/**
 * Creates an Organization (O) attribute.
 */
export function organization(value) {
  return [oid_organization, new Utf8String(value)];
}

/**
 * Creates an Organizational Unit (OU) attribute.
 */
export function organizational_unit(value) {
  return [oid_organizational_unit, new Utf8String(value)];
}

/**
 * Creates a Country (C) attribute.
 *
 * Uses PrintableString encoding as required by X.520.
 *
 * **Important:** The value must be a two-letter uppercase ISO 3166-1 alpha-2
 * country code (e.g., "US", "GB", "DE"). Non-ASCII or incorrectly formatted
 * values will produce non-compliant DER that may be rejected by CAs and clients.
 */
export function country(value) {
  return [oid_country, new PrintableString(value)];
}

/**
 * Creates a State or Province (ST) attribute.
 */
export function state(value) {
  return [oid_state, new Utf8String(value)];
}

/**
 * Creates a Locality (L) attribute.
 */
export function locality(value) {
  return [oid_locality, new Utf8String(value)];
}

/**
 * Creates an Email Address attribute.
 *
 * Note: emailAddress in the DN is deprecated; prefer using
 * Subject Alternative Names via `csr.with_email` instead.
 *
 * **Important:** The value must contain only ASCII characters.
 * Non-ASCII values will produce non-compliant DER that may be rejected
 * by CAs and clients.
 */
export function email_address(value) {
  return [oid_email_address, new Ia5String(value)];
}

export function encode_attribute_value(value) {
  if (value instanceof Utf8String) {
    let s = value[0];
    return $der.encode_utf8_string(s);
  } else if (value instanceof PrintableString) {
    let s = value[0];
    return $der.encode_printable_string(s);
  } else {
    let s = value[0];
    return $der.encode_ia5_string(s);
  }
}

export function utf8_string(value) {
  return new Utf8String(value);
}

export function printable_string(value) {
  return new PrintableString(value);
}

export function ia5_string(value) {
  return new Ia5String(value);
}

/**
 * Extracts the string value from an AttributeValue.
 *
 * Returns the underlying string regardless of encoding type
 * (UTF8String, PrintableString, or IA5String).
 */
export function attribute_value_to_string(value) {
  if (value instanceof Utf8String) {
    let s = value[0];
    return s;
  } else if (value instanceof PrintableString) {
    let s = value[0];
    return s;
  } else {
    let s = value[0];
    return s;
  }
}

function oid_to_abbrev(oid) {
  let $ = oid.components;
  if ($ instanceof $Empty) {
    let components = $;
    return $string.join($list.map(components, $int.to_string), ".");
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      let components = $;
      return $string.join($list.map(components, $int.to_string), ".");
    } else {
      let $2 = $1.tail;
      if ($2 instanceof $Empty) {
        let components = $;
        return $string.join($list.map(components, $int.to_string), ".");
      } else {
        let $3 = $2.tail;
        if ($3 instanceof $Empty) {
          let components = $;
          return $string.join($list.map(components, $int.to_string), ".");
        } else {
          let $4 = $3.tail;
          if ($4 instanceof $Empty) {
            let $5 = $.head;
            if ($5 === 2) {
              let $6 = $1.head;
              if ($6 === 5) {
                let $7 = $2.head;
                if ($7 === 4) {
                  let $8 = $3.head;
                  if ($8 === 3) {
                    return "CN";
                  } else if ($8 === 6) {
                    return "C";
                  } else if ($8 === 7) {
                    return "L";
                  } else if ($8 === 8) {
                    return "ST";
                  } else if ($8 === 10) {
                    return "O";
                  } else if ($8 === 11) {
                    return "OU";
                  } else {
                    let components = $;
                    return $string.join(
                      $list.map(components, $int.to_string),
                      ".",
                    );
                  }
                } else {
                  let components = $;
                  return $string.join(
                    $list.map(components, $int.to_string),
                    ".",
                  );
                }
              } else {
                let components = $;
                return $string.join($list.map(components, $int.to_string), ".");
              }
            } else {
              let components = $;
              return $string.join($list.map(components, $int.to_string), ".");
            }
          } else {
            let $5 = $4.tail;
            if ($5 instanceof $Empty) {
              let components = $;
              return $string.join($list.map(components, $int.to_string), ".");
            } else {
              let $6 = $5.tail;
              if ($6 instanceof $Empty) {
                let components = $;
                return $string.join($list.map(components, $int.to_string), ".");
              } else {
                let $7 = $6.tail;
                if ($7 instanceof $Empty) {
                  let $8 = $.head;
                  if ($8 === 1) {
                    let $9 = $1.head;
                    if ($9 === 2) {
                      let $10 = $2.head;
                      if ($10 === 840) {
                        let $11 = $3.head;
                        if ($11 === 113549) {
                          let $12 = $4.head;
                          if ($12 === 1) {
                            let $13 = $5.head;
                            if ($13 === 9) {
                              let $14 = $6.head;
                              if ($14 === 1) {
                                return "emailAddress";
                              } else {
                                let components = $;
                                return $string.join(
                                  $list.map(components, $int.to_string),
                                  ".",
                                );
                              }
                            } else {
                              let components = $;
                              return $string.join(
                                $list.map(components, $int.to_string),
                                ".",
                              );
                            }
                          } else {
                            let components = $;
                            return $string.join(
                              $list.map(components, $int.to_string),
                              ".",
                            );
                          }
                        } else {
                          let components = $;
                          return $string.join(
                            $list.map(components, $int.to_string),
                            ".",
                          );
                        }
                      } else {
                        let components = $;
                        return $string.join(
                          $list.map(components, $int.to_string),
                          ".",
                        );
                      }
                    } else {
                      let components = $;
                      return $string.join(
                        $list.map(components, $int.to_string),
                        ".",
                      );
                    }
                  } else {
                    let components = $;
                    return $string.join(
                      $list.map(components, $int.to_string),
                      ".",
                    );
                  }
                } else {
                  let components = $;
                  return $string.join(
                    $list.map(components, $int.to_string),
                    ".",
                  );
                }
              }
            }
          }
        }
      }
    }
  }
}

/**
 * Converts a distinguished name to a human-readable string.
 *
 * Formats the name in OpenSSL style: "CN=example.com, O=Acme Inc, C=US"
 *
 * Known OIDs are displayed with their standard abbreviations (CN, O, OU, C, ST, L).
 * Unknown OIDs are displayed in dotted-decimal notation (e.g., "1.2.3.4=value").
 */
export function name_to_string(name) {
  let rdns = name.rdns;
  let _pipe = rdns;
  let _pipe$1 = $list.flat_map(
    _pipe,
    (rdn) => {
      let attributes = rdn.attributes;
      return $list.map(
        attributes,
        (attr) => {
          let oid = attr[0];
          let value = attr[1];
          return (oid_to_abbrev(oid) + "=") + attribute_value_to_string(value);
        },
      );
    },
  );
  return $string.join(_pipe$1, ", ");
}
