enum DocumentType {
  aadhar('Aadhar Card'),
  pan('Driving License'),
  passport('Passport');

  final String displayName;
  const DocumentType(this.displayName);
}
