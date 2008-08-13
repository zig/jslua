/* javascript language executed through the lua VM */

// line comment

var function printf(format, ...) {
	print(string.format(format, ...));
}
	
{
	var a = 3;
	
	if (a < 2)
		printf("hello");
	else if (a != 2) {
		printf("hey !\n");
		a += 3;
	} else {
		a++;
		printf("yop\n");
	}

	a = (a ~= 2);
	
	a = { hello, world };
	
	Account = {
		balance = 0,
		Deposit = function(self, amount) {
			self.balance += amount;
		},
		Print = function(self) {
			printf("Account has %g\n", self.balance);
		},
	};
	
  Account:Deposit(32);
  Account:Print();
	
	printf(nil || "hello world\n");
	
}

var function pr(pv)
{
	print(v, pv);
}

for (_, v in pairs({ 1, 2, 3 }))
	pr(v);


/* completely encapsulated account */
local function CreateAccount(balance)
{
	var self;
	self = {
		Deposit = function(amount) {
			balance += amount;
		},
		Print = function() {
			printf("Account has %g\n", balance);
		},
	};

	return self;
}

local account = CreateAccount(0);
account.Deposit(32);
account.Print();

for (i = 1, 1000000, 1)
	account.Deposit(32);
//Account:Deposit(32);
