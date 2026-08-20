///|
test "parse scalar values" {
  let table = @toml-mbt.parse("s = \"hi\"\ni = 42\nf = 3.5\nb = true\n").unwrap()
  match table.get("s") {
    Some(String(s)) => assert_eq(s, "hi")
    _ => assert_true(false)
  }
  match table.get("i") {
    Some(Integer(i)) => assert_eq(i, 42L)
    _ => assert_true(false)
  }
  match table.get("f") {
    Some(Float(f)) => assert_eq(f, 3.5)
    _ => assert_true(false)
  }
  match table.get("b") {
    Some(Boolean(b)) => assert_eq(b, true)
    _ => assert_true(false)
  }
}

///|
test "parse nested tables and dotted keys" {
  let table = @toml-mbt.parse(
    "[server]\nhost = \"localhost\"\nport = 8080\n\n[database.primary]\nname = \"app\"\n",
  ).unwrap()
  match table.get("server") {
    Some(Table(s)) => {
      match s.get("host") {
        Some(String(h)) => assert_eq(h, "localhost")
        _ => assert_true(false)
      }
      match s.get("port") {
        Some(Integer(p)) => assert_eq(p, 8080L)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
  match table.get("database") {
    Some(Table(d)) =>
      match d.get("primary") {
        Some(Table(p)) =>
          match p.get("name") {
            Some(String(n)) => assert_eq(n, "app")
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "parse arrays and inline tables" {
  let table = @toml-mbt.parse("nums = [1, 2, 3]\npoint = { x = 1, y = 2 }\n").unwrap()
  match table.get("nums") {
    Some(Array(arr)) => assert_eq(arr.length(), 3)
    _ => assert_true(false)
  }
  match table.get("point") {
    Some(Table(p)) =>
      match p.get("x") {
        Some(Integer(x)) => assert_eq(x, 1L)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "parse array of tables" {
  let table = @toml-mbt.parse(
    "[[products]]\nname = \"Hammer\"\n\n[[products]]\nname = \"Nail\"\n",
  ).unwrap()
  match table.get("products") {
    Some(Array(arr)) => {
      assert_eq(arr.length(), 2)
      match arr[0] {
        Table(p) =>
          match p.get("name") {
            Some(String(n)) => assert_eq(n, "Hammer")
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "parse keeps later keys aligned after a supplementary string scalar" {
  let table = @toml-mbt.parse("emoji = \"😀\"\ntitle = \"new\"\n").unwrap()
  match table.get("emoji") {
    Some(String(value)) => assert_eq(value, "😀")
    _ => fail("expected emoji string")
  }
  match table.get("title") {
    Some(String(value)) => assert_eq(value, "new")
    _ => fail("expected title string")
  }
}

///|
test "round-trip preserves structure" {
  let text = "title = \"demo\"\ncount = 7\nenabled = true\n"
  let table = @toml-mbt.parse(text).unwrap()
  let out = @toml-mbt.serialize(table)
  let table2 = @toml-mbt.parse(out).unwrap()
  assert_eq(table == table2, true)
}

///|
test "duplicate key is an error" {
  match @toml-mbt.parse("a = 1\na = 2\n") {
    Ok(_) => assert_true(false)
    Err(_) => ()
  }
}

///|
test "invalid integer is an error" {
  match @toml-mbt.parse("a = 01\n") {
    Ok(_) => assert_true(false)
    Err(_) => ()
  }
}
