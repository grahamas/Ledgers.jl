"""
Ledgers

This package provides support for general financial ledgers

See README.md for the full documentation

Copyright 2019-2020, Eric Forgy, Scott P. Jones and other contributors

Licensed under MIT License, see LICENSE.md
"""
module Ledgers

using UUIDs, StructArrays, AbstractTrees
import Instruments
using Instruments: Position
# Although importing Instruments is enough to extend the methods below, we still import
# them explicitly so we can use them like `Ledgers.position` instead of `Instruments.position`.
# Unfortunately, `Base` also exports `position`.
import Instruments: instrument, currency, symbol, position, amount

export Identifier, AccountId, AbstractAccount, AccountWrapper, AccountNumber
export LedgerAccount, Ledger, Entry, Account, AccountGroup, ledgeraccount, add_account
export id, balance, credit!, debit!, post!
# Although the methods below are exported by Instruments, we export them explicitly 
# because we do not expect users to use `Instruments` directly.
export instrument, currency, symbol, position, amount

include("accounts.jl")

mutable struct LedgerAccount{P} <: AbstractAccount{P}
    id::AccountId
    balance::P
end

function LedgerAccount(balance::P; ledger=nothing) where {P <: Position}
    ledger === nothing && return LedgerAccount{P}(AccountId(), balance)
    acc = LedgerAccount{P}(AccountId(), balance)
    add_account!(ledger, acc)
    acc
end

LedgerAccount(::Type{P}; ledger=nothing) where {P <: Position} =
    LedgerAccount(P(0), ledger=ledger)

ledgeraccount(acc::LedgerAccount) = acc
ledgeraccount(acc::AbstractAccount) = ledgeraccount(acc.account)

balance(acc::LedgerAccount) = acc.balance
id(acc::LedgerAccount) = acc.id

struct Entry{P,A<:LedgerAccount{P}}
    debit::A
    credit::A
    amount::P
end


struct LedgerId <: Identifier
    value::UUID
end

LedgerId() = LedgerId(uuid4())

struct Ledger{P <: Position}
    id::LedgerId
    accounts::Dict{AccountId,LedgerAccount{P}}
    entries::Vector{Entry{P}}
end

function Ledger(accounts::AbstractVector{LedgerAccount{P}}, entries::AbstractVector{Entry{P}}; id=LedgerId()) where {P <: Position}
    ledger = Ledger(P)
    add_account!.(Ref(ledger), accounts)
    add_entry!.(Ref(ledger), entries)
    return ledger
end

Ledger(::Type{P}) where {P <: Position} = Ledger{P}(LedgerId(),Dict{AccountId,LedgerAccount{P}}(), Vector{Entry{P}}())

function add_account!(ledger::Ledger{P}, acc::AbstractAccount{P}) where {P <: Position}
    acc = ledgeraccount(acc)
    if id(acc) ∈ keys(ledger.accounts)
        warn("Account already in ledger.")
        return
    end
    ledger.accounts[acc.id] = acc
end

function add_accounts!(ledger::Ledger{P}, ag::AccountGroup) where P
    for acc in ag
        add_account!(ledger, acc)
    end
    ledger
end

function add_entry!(ledger::Ledger, entry::Entry)
    (id(entry.credit) ∈ keys(ledger.accounts)
        && id(entry.debit) ∈ keys(ledger.accounts)) || error("Unknown account in entry.")
    push!(ledger.entries, entry)
    post!(entry)
end


Instruments.symbol(::Type{A}) where {P, A<:AbstractAccount{P}} = symbol(P)

Instruments.currency(::Type{A}) where {P, A<:AbstractAccount{P}} = currency(P)

Instruments.instrument(::Type{A}) where {P, A<:AbstractAccount{P}} = instrument(P)

Instruments.position(::Type{A}) where {P, A<:AbstractAccount{P}} = P

Instruments.amount(acc::AbstractAccount) = amount(balance(acc))

debit!(acc::LedgerAccount, amt::Position) = (acc.balance -= amt)

credit!(acc::LedgerAccount, amt::Position) = (acc.balance += amt)

function post!(entry::Entry)
    debit!(ledgeraccount(entry.debit), entry.amt)
    credit!(ledgeraccount(entry.credit), entry.amt)
end

Base.getindex(ledger::Ledger, ix) = ledger.entries[ix]

Base.getindex(ledger::Ledger, id::AccountId) =
    ledger.accounts[id]

Base.getindex(grp::AccountGroup, id::AccountId) =
    grp.accounts[id]

# struct EntityId <: Identifier
#     value::UUID
# end

# EntityId() = EntityId(uuid4())

# struct Entity
#     id::EntityId
#     name::String
#     ledgers::Dict{Type{<:Position},Ledger{<:AbstractAccount}}
# end

# const chartofaccounts = Dict{String,AccountGroup{<:Cash}}()

# iscontra(a::AccountGroup) = !isequal(a,a.parent) && !isequal(a.parent,getledger(a)) && !isequal(a.parent.isdebit,a.isdebit)

# function loadchart(ledgername,ledgercode,csvfile)
#     data, headers = readdlm(csvfile,',',String,header=true)
#     nrow,ncol = size(data)

#     ledger = add(AccountGroup(ledgername,ledgercode))
#     for i = 1:nrow
#         row = data[i,:]
#         number = row[1]
#         name = row[2]
#         parent = chartofaccounts[row[3]]
#         isdebit = isequal(row[4],"Debit")
#         add(AccountGroup(parent,name,number,isdebit))
#     end
#     return ledger
# end

# function trim(a::AccountGroup,newparent::AccountGroup=AccountGroup(a.parent.name,a.parent.number))
#     newaccount = isequal(a,a.parent) ? newparent : AccountGroup(newparent,a.name,a.number,a.isdebit,a.balance)
#     for subaccount in a.accounts
#         balance(subaccount).a_print_account

function _print_account(io::IO, acc)
    iobuff = IOBuffer()
    isempty(acc.number.value) || print(iobuff,"[$(acc.number)] ")
    print(iobuff,acc.name,": ")
    acc.isdebit ? print(iobuff,balance(acc)) : print(iobuff,-balance(acc))
    print(io,String(take!(iobuff)))
end

Base.show(io::IO, id::Identifier) = print(io, id.value)

Base.show(io::IO, number::AccountNumber) = print(io, number.value)

Base.show(io::IO, acc::LedgerAccount) = print(io, "$(string(id(acc))): $(balance(acc))")

Base.show(io::IO, acc::AbstractAccount) = _print_account(io, acc)

Base.show(io::IO, acc::AccountGroup) = print_tree(io, acc)

Base.show(io::IO, entry::Entry) = print_tree(io, entry)

Base.show(io::IO, ledger::Ledger) = print_tree(io, ledger)

Base.show(io::IO, a::Vector{<:AbstractAccount}) = print_tree(io, a)

AbstractTrees.printnode(io::IO, acc::Ledger{P}) where {P <: Position} =
    print(io, "$(symbol(P)) Ledger: [$(acc.id)]")

AbstractTrees.children(acc::Ledger) = collect(values(acc.accounts))

AbstractTrees.printnode(io::IO, acc::AccountGroup) = _print_account(io, acc)

AbstractTrees.children(acc::AccountGroup) = vcat(collect(values(acc.subgroups)), collect(values(acc.accounts)))

AbstractTrees.printnode(io::IO, b::AbstractVector{<:AbstractAccount}) =
    isempty(b) ? print(io, "Accounts: None") : print(io, "Accounts:")

AbstractTrees.children(b::AbstractVector{<:AbstractAccount}) = b

AbstractTrees.children(entry::Entry) = [entry.debit, entry.credit]

AbstractTrees.printnode(io::IO, ::Entry) = print(io, "Entry:")

end # module Ledgers
