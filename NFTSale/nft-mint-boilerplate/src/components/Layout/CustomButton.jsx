function CustomButton(props) {
  return (
    <button
      className={`bg-yellow-500 border-slate-100 border py-2 px-4 rounded-3xl hover:border-slate-300 active:border-slate-700 focus:border-slate-500 transition duration-150 ease-out ${props.className}`}
      onClick={props.onClick ? props.onClick : () => { }}>
      {props.text}
    </button>
  )
}

export default CustomButton
