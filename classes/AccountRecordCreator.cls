public class AccountRecordCreator {

    public static Id createAccount(String accountName, String phone, String website) {
        Account acc = new Account();
        acc.Name = accountName;
        acc.Phone = phone;
        acc.Website = website;

        insert acc;

        return acc.Id;
    }
}