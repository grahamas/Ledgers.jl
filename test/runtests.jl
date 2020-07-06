using Ledgers
import Test; using Test: @testset, @test
using Assets: USD

function example()
    group = AccountGroup(USD, AccountNumber("0000000"), "Account Group", true)
    assets = AccountGroup(USD, AccountNumber("1000000"), "Assets", true, parent=group)
    liabilities = AccountGroup(USD, AccountNumber("2000000"), "Liabilities", false, parent=group)
    cash = Account(USD, AccountNumber("1010000"), "Cash", true, parent=assets)
    payable = Account(USD, AccountNumber("2010000"), "Accounts Payable", false, parent=liabilities)

    entry = Entry(cash, payable)
    group, assets, liabilities, cash, payable, entry
end

group, assets, liabilities, cash, payable, entry = example()

@testset "Account creation" begin
    @test id(group) isa AccountId
    @test id(assets) isa AccountId
    @test cash.number.value === "1010000"
    @test payable.name === "Accounts Payable"
    @test assets.iscontra === false
    @test liabilities.iscontra === true
    @test balance(group) === 0USD
    @test balance(assets) === 0USD
    @test balance(liabilities) === 0USD
end

@testset "Post entry" begin
    amt = 10USD
    post!(entry, amt)
    @test balance(group) === 0USD
    @test balance(assets) === amt
    @test balance(liabilities) === -amt
    @test balance(cash) === amt
    @test balance(payable) === -amt
end