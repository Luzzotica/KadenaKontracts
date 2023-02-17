import { applyMiddleware, configureStore, createStore } from '@reduxjs/toolkit'
import thunkMiddleware from 'redux-thunk'
import rootReducer from './rootReducer'

const composedEnhancer = applyMiddleware(thunkMiddleware);

export default createStore(rootReducer, composedEnhancer);
// configureStore({
//   reducer: rootReducer,
//   middleware: getDefaultMiddleware => [...getDefaultMiddleware(), applyMiddleware(thunkMiddleware)],
// });