# Ruby vs SQL Antipatterns (full ❌/✅ pairs)

Common patterns where Ruby is used instead of SQL, causing major performance issues.
The SKILL.md body keeps only a trigger table; the worked code pairs live here.

## 1. Ruby Filtering Instead of SQL WHERE

```bash
# Find Ruby filtering on AR collections - HIGH RISK
grep -rn "\.all\.select\s*{\|\.all\.map\s*{\|\.all\.reject\s*{" app/ --include="*.rb"
grep -rn "\.to_a\.select\|\.to_a\.map\|\.to_a\.reject" app/ --include="*.rb"
```
**Expected**: 0 matches (use `.where()` instead)

```ruby
# ❌ BAD - Loads ALL records, filters in Ruby (O(n) memory)
User.all.select { |u| u.active? }
facility.memberships.to_a.select { |m| m.status == 'active' }

# ✅ GOOD - SQL does the filtering (O(1) memory)
User.where(active: true)
facility.memberships.where(status: 'active')
```

## 2. .length on Associations Instead of .count

```bash
# Find .length on associations - MEDIUM RISK
grep -rn "\.members\.length\|\.users\.length\|\.reservations\.length\|\.memberships\.length" app/ --include="*.rb"
grep -rn "\.\w\+s\.length" app/ --include="*.rb" | grep -v "string\|array\|\.to_s\|\.to_a"
```
**Expected**: 0 matches (use `.count` or `.size`)

```ruby
# ❌ BAD - Loads all records just to count them
facility.users.length      # SELECT * FROM users → Array#length
facility.reservations.length

# ✅ GOOD - SQL count
facility.users.count       # SELECT COUNT(*) FROM users
facility.reservations.size # Uses count if not loaded, length if loaded
```

## 3. .where(...).present? Instead of .exists?

```bash
# Find .present? on queries - MEDIUM RISK
grep -rn "\.where(.*).present?\|\.where(.*).any?\|\.where(.*).blank?" app/ --include="*.rb"
```
**Expected**: 0 matches (use `.exists?` for existence checks)

```ruby
# ❌ BAD - Loads record(s) just to check existence
User.where(email: email).present?   # SELECT * FROM users WHERE email = ...
User.where(email: email).any?       # Same problem

# ✅ GOOD - Only checks existence (SELECT 1 ... LIMIT 1)
User.exists?(email: email)
User.where(email: email).exists?
```

## 4. Ruby Aggregation Instead of SQL

```bash
# Find Ruby .sum/.max/.min on collections - MEDIUM RISK
grep -rn "\.map.*\.sum\|\.pluck.*\.sum\|\.map.*\.max\|\.map.*\.min" app/ --include="*.rb"
```
**Expected**: Review each - most can use `Model.sum(:column)` instead

```ruby
# ❌ BAD - Loads all records, aggregates in Ruby
facility.payments.map(&:amount).sum    # Loads all payment objects
facility.memberships.pluck(:price).sum # Better, but still loads array

# ✅ GOOD - SQL aggregation
facility.payments.sum(:amount)          # SELECT SUM(amount) FROM payments
facility.memberships.maximum(:price)    # SELECT MAX(price)
```

## 5. String Concatenation in Loops

```bash
# Find string += in loops - PERFORMANCE RISK
grep -rn '+= "' app/ --include="*.rb"
grep -B5 '+= "' app/ --include="*.rb" | grep "each\|map\|loop\|while\|for"
```
**Expected**: 0 matches in loops (use `Array#join` or `StringIO`)

```ruby
# ❌ BAD - String concatenation is O(n²) in loops
result = ""
users.each { |u| result += "#{u.name}\n" }

# ✅ GOOD - Array#join is O(n)
result = users.map { |u| u.name }.join("\n")
```
