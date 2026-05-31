String encodedAddressWord(String address) =>
    address.substring(2).toLowerCase().padLeft(64, '0');
