import { CustomType as $CustomType } from "./gleam.mjs";

export class ReplaceHtml extends $CustomType {
  constructor(id, html) {
    super();
    this.id = id;
    this.html = html;
  }
}
export const Command$ReplaceHtml = (id, html) => new ReplaceHtml(id, html);
export const Command$isReplaceHtml = (value) => value instanceof ReplaceHtml;
export const Command$ReplaceHtml$id = (value) => value.id;
export const Command$ReplaceHtml$0 = (value) => value.id;
export const Command$ReplaceHtml$html = (value) => value.html;
export const Command$ReplaceHtml$1 = (value) => value.html;

export class SetAttr extends $CustomType {
  constructor(id, name, value) {
    super();
    this.id = id;
    this.name = name;
    this.value = value;
  }
}
export const Command$SetAttr = (id, name, value) =>
  new SetAttr(id, name, value);
export const Command$isSetAttr = (value) => value instanceof SetAttr;
export const Command$SetAttr$id = (value) => value.id;
export const Command$SetAttr$0 = (value) => value.id;
export const Command$SetAttr$name = (value) => value.name;
export const Command$SetAttr$1 = (value) => value.name;
export const Command$SetAttr$value = (value) => value.value;
export const Command$SetAttr$2 = (value) => value.value;

export class RemoveAttr extends $CustomType {
  constructor(id, name) {
    super();
    this.id = id;
    this.name = name;
  }
}
export const Command$RemoveAttr = (id, name) => new RemoveAttr(id, name);
export const Command$isRemoveAttr = (value) => value instanceof RemoveAttr;
export const Command$RemoveAttr$id = (value) => value.id;
export const Command$RemoveAttr$0 = (value) => value.id;
export const Command$RemoveAttr$name = (value) => value.name;
export const Command$RemoveAttr$1 = (value) => value.name;

export class LocalizeDates extends $CustomType {}
export const Command$LocalizeDates$const = new LocalizeDates();
export const Command$LocalizeDates = () => Command$LocalizeDates$const;
export const Command$isLocalizeDates = (value) =>
  value instanceof LocalizeDates;

export class RewriteRemoteImages extends $CustomType {}
export const Command$RewriteRemoteImages$const = new RewriteRemoteImages();
export const Command$RewriteRemoteImages = () =>
  Command$RewriteRemoteImages$const;
export const Command$isRewriteRemoteImages = (value) =>
  value instanceof RewriteRemoteImages;
