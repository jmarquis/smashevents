import classNames from "classnames"
import { useCombobox } from "downshift"
import { useEffect, useState } from "react"

import PlayerIcon from "@/icons/user.svg?react"
import ClearIcon from "@/icons/x.svg?react"

const currentTag = document.body.dataset["currentTag"]
const past = window.location.href.includes("/past")

export default () => {
  const [inputValue, setInputValue] = useState(currentTag || "")
  const [selectedItem, setSelectedItem] = useState(currentTag || null)
  const [items, setItems] = useState(selectedItem ? [selectedItem] : [])

  useEffect(() => {
    if (inputValue.length < 2 && items && items.length) {
      setItems([])
      return
    }

    ;(async () => {
      const response = await fetch(`/players/search?q=${inputValue}`)
      const data = await response.json()
      setItems(data.results || [])
    })()
  }, [inputValue])

  const {
    isOpen,
    getMenuProps,
    getInputProps,
    highlightedIndex,
    getItemProps
  } = useCombobox({
    onInputValueChange({ inputValue }) {
      setInputValue(inputValue)
    },
    inputValue,
    items,
    itemToString(item) {
      return item || ""
    },
    selectedItem,
    onSelectedItemChange({ selectedItem }) {
      setSelectedItem(selectedItem)
      window.location.href = `/players/${selectedItem}`
    },
    defaultHighlightedIndex: 0
  })

  function handleInputFocus() {
    if (inputValue === selectedItem) {
      setInputValue("")
    }
  }

  function handleInputBlur() {
    if (currentTag) {
      setInputValue(currentTag)
      setSelectedItem(currentTag)
    }
  }

  function handleClearClick() {
    if (currentTag) {
      window.location.href = past ? "/past" : "/"
    } else {
      setInputValue("")
    }
  }

  return (
    <div
      className={classNames("PlayerSelector", {
        "item-selected": selectedItem
      })}
    >
      <input
        type="text"
        placeholder="Filter by player..."
        {...getInputProps({
          onFocus: handleInputFocus,
          onBlur: handleInputBlur
        })}
      />
      <PlayerIcon />
      <button type="button" className="clear" onClick={handleClearClick}>
        <ClearIcon />
      </button>
      <ul
        className={classNames("menu", {
          hidden: !isOpen || !items.length
        })}
        {...getMenuProps()}
      >
        {isOpen &&
          items.map((item, index) => (
            <li
              key={item}
              className={classNames({
                highlighted: index === highlightedIndex,
                selected: item === selectedItem
              })}
              {...getItemProps({ item: item, index })}
            >
              {item}
            </li>
          ))}
      </ul>
    </div>
  )
}
