var phoneNumber = String(CLERK_TEST_PHONE_NUMBER).replace(/\D/g, "");

if (phoneNumber.length !== 10) {
  throw new Error("CLERK_TEST_PHONE_NUMBER must contain exactly 10 digits");
}

for (var index = 0; index < phoneNumber.length; index += 1) {
  output["phoneDigit" + index] = phoneNumber.charAt(index);
}
